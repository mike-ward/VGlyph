# Pitfalls Research: Performance Optimization

**Domain:** Text renderer performance (shelf packing, async GPU, shape caching)
**Researched:** 2026-02-04
**Context:** v1.6 milestone — adding optimization features to existing VGlyph renderer

## Summary

Key risks center on maintaining correctness while optimizing. VGlyph already has stable LRU caches,
multi-page atlas, and error propagation. Integration pitfalls:

1. **Shelf packing fragmentation** — vertical fragmentation from partial shelf resets, wasted space
   from shelf height choices
2. **Async upload races** — single-threaded V doesn't need mutexes, but upload timing with rendering
   still requires careful ordering
3. **Shape cache invalidation** — font changes, size changes, feature changes all invalidate plans,
   easy to miss edge cases
4. **Integration with existing LRU** — new caches interact with glyph cache, layout cache, metrics
   cache — eviction coordination needed

V is single-threaded by design, eliminating many async pitfalls. Focus on correctness, not
concurrency.

---

## Shelf Packing Pitfalls

### 1. Vertical Fragmentation from Partial Page Reset

**What happens:**
Shelf packer allocates multiple shelves per page. When page fills, current code resets entire
oldest page. With shelf packing, may want to reset individual shelves, but middle shelves stay
allocated while top/bottom are reset, causing vertical fragmentation — unusable gaps in middle
of page.

**Warning signs:**
- Atlas utilization drops over time (used_pixels / total_pixels decreases)
- Large glyphs fail to allocate despite plenty of total free space
- Multiple shelves with small gaps, none large enough for next glyph
- Profile metrics show low utilization but frequent resets

**Why it happens:**
- Shelf allocator fills shelves top-to-bottom
- LRU eviction marks oldest shelf for reset
- Adjacent shelves may still be active
- Can't merge non-contiguous free shelves without full page reset
- Mozilla WebRender docs: "Only top-most shelf removed when empty, consecutive empty shelves in
  middle aren't merged until they become top-most shelves"

**Prevention:**
- Reset entire page, not individual shelves (simpler, avoids fragmentation)
- OR: Track per-shelf age, only reset when all shelves above are empty
- OR: Use column-based splitting to reduce shelf size (more smaller shelves = less waste per shelf)
- Existing code resets entire page — keep this behavior when adding shelf packing
- Test: Fill page with mixed glyph sizes, evict half, verify no unusable gaps

**Phase to address:** Shelf packing implementation

**Confidence:** HIGH
Sources: [Mozilla WebRender shelf allocator](https://nical.github.io/posts/etagere.html),
[Bugzilla 1679751](https://bugzilla.mozilla.org/show_bug.cgi?id=1679751)

---

### 2. Shelf Height Choice Causing Wasted Space

**What happens:**
First glyph in shelf determines shelf height. Small glyph creates short shelf, wasting space when
later glyphs are taller. Large emoji creates tall shelf, wasting space for subsequent small glyphs.

**Warning signs:**
- Many short shelves with large gaps at top
- Tall shelf with single large glyph followed by empty space
- Atlas utilization < 70% (industry target: 75-80%)
- Visual inspection shows horizontal bands of wasted space

**Why it happens:**
- Simple shelf packer: shelf height = first glyph height
- Glyph arrival order random (depends on text content)
- No pre-sorting by height
- Trade-off: pre-sorting adds complexity, dynamic allocation simpler

**Prevention:**
- Use multiple shelf height bins: small (0-32px), medium (32-64px), large (64-256px)
- Route glyphs to appropriate bin
- OR: Start with minimum shelf height (e.g., 32px), grow if needed
- Existing GlyphAtlas uses row_height tracking — extend to support bins
- Test: Mix of ASCII (12px), CJK (24px), emoji (128px), verify utilization > 75%

**Phase to address:** Shelf packing implementation

**Confidence:** MEDIUM
Sources: [lisyarus texture packing blog](https://lisyarus.github.io/posts/texture-packing.html),
[Stray Pixels font packing](https://straypixels.net/texture-packing-for-fonts/)

---

### 3. Integration with Existing Multi-Page Atlas

**What happens:**
Current code: multi-page atlas with LRU page eviction. Adding shelf packing per-page changes
eviction granularity. May reset page with mostly-valid glyphs because one shelf is stale.

**Warning signs:**
- Glyph cache hit rate drops after shelf packing added
- Entire page reset when only one shelf is old
- Frequent atlas resets despite low overall usage
- Profile metrics: atlas_resets increases significantly

**Why it happens:**
- Existing code: page age = last access to any glyph on page
- Shelf packing: multiple shelves per page with different ages
- Page LRU tracks page-level age, doesn't account for per-shelf age
- Resetting page invalidates all glyphs, including recently-used ones on other shelves

**Prevention:**
- Option 1: Keep page-level LRU, reset entire page (simpler, matches current code)
- Option 2: Track per-shelf age, reset only oldest shelf (complex, requires partial page reset)
- Option 3: Multi-level eviction: shelf-level eviction within page, page-level eviction across
  atlas
- Recommendation: Option 1 for initial implementation (matches existing behavior)
- Test: Render mixed text, verify glyph cache hit rate doesn't regress

**Phase to address:** Shelf packing integration with existing GlyphAtlas

**Confidence:** HIGH (VGlyph-specific, based on existing code review)

---

### 4. Glyph Cache Key Collision After Atlas Reset

**What happens:**
Shelf packing adds shelf_id to glyph allocation. Atlas page reset invalidates glyphs. Glyph cache
still has stale entries pointing to old shelf positions. New glyph allocated at same position,
cache returns wrong glyph.

**Warning signs:**
- Visual corruption: wrong glyphs displayed
- Debug build panic: "Glyph cache collision" (existing secondary key check)
- Glyphs flicker between correct and incorrect
- Corruption appears after atlas reset, not before

**Why it happens:**
- Glyph cache key: `(font_face XOR (glyph_index << 2) | subpixel_bin)`
- Cache value: `CachedGlyph { x, y, width, height, page, ... }`
- Atlas reset clears page data but doesn't update cache
- Existing code handles this: after reset, deletes all cache entries for reset page
  (glyph_atlas.v:312-318)
- Shelf packing must preserve this invalidation

**Prevention:**
- After shelf/page reset, iterate glyph cache and delete entries where `page == reset_page`
- Existing code already does this (renderer.v:313-317)
- Don't break this when adding shelf tracking
- Secondary key validation catches this in debug builds (renderer.v:336-342)
- Test: Debug build, fill atlas, reset page, verify no collision panics

**Phase to address:** Shelf packing integration

**Confidence:** HIGH (existing code pattern, must preserve)

---

## Async Texture Updates Pitfalls

### 5. Upload-After-Draw Ordering Bug

**What happens:**
GPU texture upload occurs after draw calls that reference the texture. Glyphs render with stale
atlas data (previous frame or uninitialized).

**Warning signs:**
- Glyphs appear blank on first frame, correct on second frame
- New glyphs flicker or show garbage
- Issue disappears with artificial delays
- Metal validation layer warnings (if enabled)

**Why it happens:**
- Existing VGlyph flow: draw → commit → upload (glyph_atlas.v + renderer.v:105-118)
- Current commit() uploads all dirty pages after batched draws
- If async upload defers actual GPU upload, draw may execute before upload completes
- V is single-threaded, but GPU commands are async by nature

**Prevention:**
- V is single-threaded: no CPU race conditions
- GPU command ordering: ensure upload commands issued before draw commands in same frame
- Sokol/gg batching: calls are queued, executed in order
- Current code safe: commit() → update_pixel_data() → draws happen next frame
- Async optimization must preserve ordering: upload submitted before draws, but may complete later
- Use Sokol frame sync, don't break existing commit() pattern
- Test: Render new text, verify glyphs visible immediately (no blank frame)

**Phase to address:** Async upload implementation

**Confidence:** MEDIUM (V's single-threaded nature simplifies, but GPU async still applies)
Sources: [OpenGL Buffer Streaming](https://www.khronos.org/opengl/wiki/Buffer_Object_Streaming),
[Songho PBO Tutorial](https://www.songho.ca/opengl/gl_pbo.html)

---

### 6. Double-Buffering PBO Complexity vs Single-Threaded V

**What happens:**
Many async upload tutorials use double-buffering PBOs to avoid stalls. Developer adds complexity
inappropriate for single-threaded V, introducing bugs without performance gain.

**Warning signs:**
- Complex buffer swap logic
- Tracking "current" vs "next" buffer state
- Synchronization primitives (not needed in V)
- Code complexity increased significantly
- Performance gain negligible or zero

**Why it happens:**
- Multi-threaded engines: double-buffer to upload next frame while GPU reads current frame
- V is single-threaded: CPU doesn't do other work during GPU upload anyway
- Tutorials assume multi-threaded context
- Developer over-engineers based on generic advice

**Prevention:**
- V constraint: single-threaded by design
- Use single PBO or simple buffer orphaning technique
- OpenGL: glBufferData(NULL) orphans old buffer, allocates new (driver handles async)
- Sokol: sg_update_image() with .dynamic usage already handles this
- Don't add threading primitives (V doesn't support them)
- Test: Profile actual upload time, verify optimization needed before adding complexity

**Phase to address:** Async upload design

**Confidence:** HIGH (V language constraint)
Sources: [V Programming Language](https://vlang.io/), [Memory Safe Languages](https://en.wikipedia.org/wiki/Memory_safety)

---

### 7. Atlas Grow During Upload Corruption

**What happens:**
Async upload in progress when atlas page grows. New allocation changes page dimensions, upload
writes to wrong offsets, visual corruption or crash.

**Warning signs:**
- Corruption appears when atlas grows
- Crash in upload code (out of bounds)
- Glyphs garbled after atlas resize
- Atlas grow fails unexpectedly

**Why it happens:**
- Current flow: insert_bitmap → copy to page.image.data → mark dirty → commit uploads
- Atlas grow: allocates new buffer, copies old data, updates page.image
- If upload references old page.image pointer during grow, stale data
- Existing code handles this: grow() creates new Sokol image, defers old image destruction
  (glyph_atlas.v:655)

**Prevention:**
- Existing cleanup() mechanism prevents use-after-free (glyph_atlas.v:694-701)
- Don't upload during grow: mark dirty, upload on next commit()
- Current code safe: grow happens during insert, upload happens during commit (separate phases)
- Async optimization must preserve separation: don't start upload until grow complete
- Test: Force atlas grow (insert large glyphs), verify no corruption

**Phase to address:** Async upload integration with existing grow()

**Confidence:** HIGH (existing code pattern, must preserve)

---

## Shape Plan Caching Pitfalls

### 8. Shape Plan Invalidation on Font Change

**What happens:**
User changes font. Shape plan cache contains plans for old font. New text shaped with old plan,
wrong glyphs or crash.

**Warning signs:**
- Font change doesn't take effect
- Glyphs from old font displayed
- Crash when drawing with new font (invalid FT_Face)
- Memory corruption after font switch

**Why it happens:**
- HarfBuzz shape plan includes font face reference
- Shape plan caching uses font as part of cache key
- If key doesn't include font identity, plans reused across fonts
- Font pointer reused (memory address same), cache hit with stale plan

**Prevention:**
- Cache key MUST include font identity: (font_face_ptr, font_size, features, script, language)
- Existing metrics cache key: `face_ptr XOR size` (glyph_atlas.v:318)
- Shape plan cache key: extend to include features/script/language
- Font change: clear cache OR rely on pointer change invalidating entries
- VGlyph: font face from Pango, lifetime managed by PangoFont
- Test: Render text, change font, render again, verify correct glyphs

**Phase to address:** Shape plan cache key design

**Confidence:** HIGH
Sources: [HarfBuzz Plans and Caching](https://harfbuzz.github.io/shaping-plans-and-caching.html),
[HarfBuzz Shape Plan API](https://harfbuzz.github.io/harfbuzz-hb-shape-plan.html)

---

### 9. Shape Plan Cache Memory Bloat

**What happens:**
Shape plan cache grows unbounded. Each unique (font, size, features, script, language) tuple
creates new plan. Application renders text in many languages/fonts, cache explodes.

**Warning signs:**
- Memory usage increases over time
- Cache hit rate low (many unique keys)
- Slowdown over long session
- Memory profiler shows large HarfBuzz allocations

**Why it happens:**
- Shape plans are per-combination of font/features/script/language
- Real-world apps: multiple fonts, sizes, languages
- Combinatorial explosion: 5 fonts × 3 sizes × 10 languages = 150 plans
- HarfBuzz doesn't auto-evict cached plans
- Reference counting: plans survive until unreferenced

**Prevention:**
- Implement LRU eviction for shape plan cache (match existing glyph/metrics cache pattern)
- Existing metrics cache: 256 entries (glyph_atlas.v, PROJECT.md:43)
- Shape plan cache: similar size, 256-512 entries
- Reference counting: `hb_shape_plan_reference()` / `hb_shape_plan_destroy()`
- Cache per-font or global: global better (shared across text systems)
- Test: Render text in 50 different fonts, verify cache doesn't exceed limit

**Phase to address:** Shape plan cache implementation

**Confidence:** MEDIUM
Sources: [HarfBuzz Shape Plan Reference Counting](https://harfbuzz.github.io/harfbuzz-hb-shape-plan.html)

---

### 10. Font Size Change Invalidation Miss

**What happens:**
Shape plan cached at 12pt. Text rendered at 14pt reuses 12pt plan. Glyphs shaped incorrectly
(wrong spacing, wrong substitutions if size affects features).

**Warning signs:**
- Text layout incorrect after size change
- Spacing wrong
- Optical size features not applied
- Ligatures appear/disappear incorrectly

**Why it happens:**
- Font size affects shaping: some fonts have size-specific substitutions
- OpenType 'size' feature: optical sizing
- Cache key omits size or uses wrong granularity (logical vs device pixels)
- VGlyph uses physical pixels: `target_height * scale_factor`

**Prevention:**
- Cache key includes font size: use physical pixel size (match glyph rasterization)
- Existing pattern: FT_Set_Pixel_Sizes(target_height) before rasterization
- Shape plan key: include target_height (not logical size, not DPI-scaled)
- Pango handles DPI scaling, VGlyph uses result directly
- Test: Render at 12pt, change to 14pt, verify new shaping

**Phase to address:** Shape plan cache key design

**Confidence:** HIGH (VGlyph-specific, based on existing font handling)

---

### 11. OpenType Features Hash Collision

**What happens:**
Cache key hashes feature list poorly. Different feature sets collide, wrong plan used. Text with
ligatures renders without, or vice versa.

**Warning signs:**
- Ligatures intermittent (appear/disappear)
- Font features not consistently applied
- Small changes to text affect unrelated text rendering
- Debug: multiple feature sets map to same cache key

**Why it happens:**
- Feature list is variable-length array of (tag, value) pairs
- Simple hash: XOR of feature tags → collisions
- Feature order matters for some fonts, ignored by naive hash
- Example collision: [liga=1, dlig=0] vs [dlig=0, liga=1] (same XOR)

**Prevention:**
- Use robust hash for feature list: FNV-1a or similar (existing layout cache uses FNV-1a)
- Hash includes feature tag, value, and order
- OR: canonicalize feature list (sort by tag) before hashing
- Existing layout cache pattern: FNV-1a over all config fields (api.v)
- Apply same pattern to shape plan features
- Test: Render with liga=1, render with liga=0, verify different results

**Phase to address:** Shape plan cache key design

**Confidence:** HIGH (existing pattern in VGlyph layout cache)

---

## Integration Pitfalls

### 12. Three-Level Cache Coordination

**What happens:**
VGlyph now has three caches: layout cache (TTL), glyph cache (LRU), shape plan cache (new).
Eviction uncoordinated. Shape plan evicted but glyphs remain, or layout evicted but shape plan
remains, wasting memory.

**Warning signs:**
- Memory usage higher than expected
- One cache full while others empty
- Eviction of one cache doesn't free related entries in others
- Cache hit rates imbalanced (one high, others low)

**Why it happens:**
- Layout cache: hash of (text, config), stores Pango layout result
- Shape plan cache: hash of (font, size, features), stores HarfBuzz plan
- Glyph cache: hash of (font, glyph_index, bin), stores atlas position
- No explicit link between caches
- Shape plan used during layout creation, not stored in Layout
- Layout eviction doesn't notify shape plan cache

**Prevention:**
- Accept uncoordinated eviction (simpler, acceptable memory overhead)
- Each cache manages own eviction independently
- Shape plan cache: moderate size (256 entries), LRU is sufficient
- Existing caches don't coordinate: layout cache (10K entries), glyph cache (4096 entries),
  metrics cache (256 entries)
- Adding shape cache (256 entries) consistent with current approach
- Monitor total memory, not individual cache coordination
- Test: Long session with varied text, verify total memory reasonable

**Phase to address:** Shape plan cache implementation

**Confidence:** MEDIUM (VGlyph design decision)

---

### 13. Layout Cache Hit Prevents Shape Plan Cache Hit

**What happens:**
Text rendered, layout cached. Same text rendered again, layout cache hit, Pango layout reused,
shape plan cache never queried (HarfBuzz not called). Shape plan cache appears unused, developer
questions value.

**Warning signs:**
- Shape plan cache hit rate near zero
- Shape plan cache always misses despite repeated text
- Layout cache hit rate high (good), shape plan irrelevant
- Profiling shows HarfBuzz barely called

**Why it happens:**
- Layout cache is higher level: caches entire Pango layout (includes shaping result)
- Layout cache hit skips shaping entirely
- Shape plan cache only helps on layout cache miss
- Shape plan optimization only matters for new/uncached text

**Prevention:**
- This is correct behavior: layout cache is primary, shape plan cache is fallback
- Shape plan cache still valuable: improves perf when layout cache misses
- Layout cache limited (10K entries), evicts on TTL (PROJECT.md:92)
- Long-running apps: layout cache churn means frequent shape plan cache hits
- Profile in realistic scenario: varied text, not same string repeated
- Don't expect shape plan cache high hit rate in benchmarks (layout cache dominates)
- Test: Render 50K unique strings, observe shape plan cache hits after layout evictions

**Phase to address:** Shape plan cache evaluation

**Confidence:** HIGH (cache hierarchy understanding)

---

### 14. HarfBuzz Shape Plan Lifetime Management

**What happens:**
Shape plan cached but not reference-counted correctly. HarfBuzz destroys plan while cache still
references it. Use-after-free, crash or corruption.

**Warning signs:**
- Crash in HarfBuzz during shaping
- Corruption in shaped text
- Valgrind/ASan: use-after-free in hb_shape_plan_*
- Crash intermittent (timing-dependent)

**Why it happens:**
- HarfBuzz uses reference counting: `hb_shape_plan_reference()` / `hb_shape_plan_destroy()`
- Cache must hold reference while plan is cached
- On cache eviction: must call `hb_shape_plan_destroy()` to release reference
- If cache stores plan without reference, HarfBuzz may destroy underlying data

**Prevention:**
- When caching plan: `hb_shape_plan_reference()` to increment refcount
- When evicting from cache: `hb_shape_plan_destroy()` to decrement refcount
- Use `hb_shape_plan_create_cached()` (HarfBuzz manages refcount) OR manual reference
- V's manual memory management: must pair reference/destroy explicitly
- Existing pattern: FreeType face managed by Pango (VGlyph doesn't free)
- Test: Valgrind/ASan build, fill cache, evict, verify no leaks/use-after-free

**Phase to address:** Shape plan cache implementation

**Confidence:** HIGH
Sources: [HarfBuzz Reference Counting](https://harfbuzz.github.io/harfbuzz-hb-shape-plan.html)

---

### 15. Existing Pango Layout Cache Subsumes Shape Plan Cache

**What happens:**
VGlyph's layout cache already caches Pango layout, which internally caches HarfBuzz shape plans.
Adding explicit shape plan cache duplicates work, increases complexity without benefit.

**Warning signs:**
- Shape plan cache provides no measurable performance improvement
- Profiling shows HarfBuzz time unchanged
- Code complexity increased, benefit unclear
- Cache memory increased, hit rate low

**Why it happens:**
- Pango internally uses HarfBuzz for shaping
- Pango may cache shape plans internally (implementation detail)
- VGlyph caches entire PangoLayout (includes shaping result)
- Layout cache hit skips HarfBuzz entirely
- Shape plan cache only matters if layout cache misses frequently

**Prevention:**
- Profile BEFORE implementing shape plan cache
- Measure: layout cache miss rate, time spent in pango_layout_get_iter (includes shaping)
- If layout cache miss rate < 5%, shape plan cache adds little value
- Existing PROJECT.md: layout cache with TTL eviction (api.v:92)
- Consider: increase layout cache size before adding shape plan cache
- Test: Profile with realistic workload, measure actual HarfBuzz time
- Recommendation: Implement shape plan cache only if profiling shows layout cache insufficient

**Phase to address:** Before shape plan cache implementation (profiling phase)

**Confidence:** MEDIUM (depends on actual workload characteristics)

---

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation |
|-------|---------------|------------|
| Shelf packing impl | Vertical fragmentation (1) | Reset entire page, not individual shelves |
| Shelf packing impl | Shelf height waste (2) | Use height bins (small/med/large) |
| Shelf packing integ | Page eviction breaks glyphs (3) | Keep page-level LRU, reset entire page |
| Shelf packing integ | Cache invalidation after reset (4) | Preserve existing cache deletion loop |
| Async upload impl | Upload-after-draw (5) | Preserve commit() → draws ordering |
| Async upload design | Over-engineering for V (6) | Single PBO, no threading primitives |
| Async upload integ | Grow during upload (7) | Preserve existing cleanup() deferred destroy |
| Shape cache design | Font change invalidation (8) | Include font_face ptr in cache key |
| Shape cache impl | Memory bloat (9) | LRU eviction, 256 entry limit like metrics cache |
| Shape cache design | Size change invalidation (10) | Include physical pixel size in cache key |
| Shape cache design | Feature hash collision (11) | FNV-1a hash like existing layout cache |
| Shape cache integ | Three-level cache coordination (12) | Accept independent eviction, monitor total mem |
| Shape cache eval | Layout cache prevents hits (13) | Profile in realistic scenario (varied text) |
| Shape cache impl | HarfBuzz lifetime management (14) | reference() on cache, destroy() on evict |
| Shape cache decision | Pango already caches (15) | Profile BEFORE implementing, may not be needed |

---

## Testing Strategy

**Shelf packing verification:**
```
Fill atlas with varied glyph sizes:
- 100 ASCII glyphs (12px)
- 50 CJK glyphs (24px)
- 10 emoji (128px)
Verify utilization > 75%
Force page reset, verify no visual corruption
Debug build: verify no cache collision panics
```

**Async upload verification:**
```
Render new text each frame (no cache hits)
Verify glyphs visible immediately (no blank frame)
Profile upload time vs synchronous baseline
Force atlas grow mid-session, verify no corruption
```

**Shape plan cache verification:**
```
Render 10K unique strings (layout cache misses)
Verify shape plan cache hits > 80% after warmup
Change font, verify old plans not used
Valgrind: verify no leaks on cache eviction
Profile: verify HarfBuzz time reduced vs no cache
```

**Integration verification:**
```
Long session with varied text:
- Monitor total memory usage (all caches)
- Profile cache hit rates (layout, glyph, shape)
- Verify atlas utilization stable
- Verify no visual corruption
- Debug build: verify no panics
```

---

## Open Questions

- Shelf packing: height bins vs dynamic growth? (bins simpler, less fragmentation)
- Async upload: needed for single-threaded V? (profile first, may be GPU-bound not CPU-bound)
- Shape cache: Pango internal caching sufficient? (profile before implementing)

---

## Sources

**HIGH confidence:**
- [Eight Million Pixels: WebRender etagere](https://nical.github.io/posts/etagere.html)
- [Mozilla Bugzilla 1679751: Shelf allocator](https://bugzilla.mozilla.org/show_bug.cgi?id=1679751)
- [OpenGL Buffer Streaming](https://www.khronos.org/opengl/wiki/Buffer_Object_Streaming)
- [Songho OpenGL PBO](https://www.songho.ca/opengl/gl_pbo.html)
- [HarfBuzz Plans and Caching](https://harfbuzz.github.io/shaping-plans-and-caching.html)
- [HarfBuzz Shape Plan API](https://harfbuzz.github.io/harfbuzz-hb-shape-plan.html)

**MEDIUM confidence:**
- [lisyarus Texture Packing](https://lisyarus.github.io/posts/texture-packing.html)
- [Stray Pixels Font Packing](https://straypixels.net/texture-packing-for-fonts/)
- [V Programming Language](https://vlang.io/)
- [LRU Cache Pitfalls](https://www.shadecoder.com/topics/what-is-lru-cache-a-practical-guide-for-2025)
- [Cache Eviction Strategies](https://www.designgurus.io/blog/cache-eviction-strategies)

**VGlyph codebase (HIGH confidence):**
- glyph_atlas.v: Multi-page atlas, LRU eviction, grow() deferred cleanup
- renderer.v: Glyph cache invalidation loop, secondary key validation
- api.v: Layout cache FNV-1a hashing
- PROJECT.md: Cache sizes, architectural decisions
