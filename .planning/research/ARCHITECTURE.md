# Architecture Research: Performance Optimization

**Domain:** Text rendering library performance enhancement
**Researched:** 2026-02-04
**Confidence:** MEDIUM

## Current Architecture

VGlyph uses row-based atlas allocation with multi-page support:

**GlyphAtlas (glyph_atlas.v):**
- Multi-page: 4 max pages, LRU page eviction
- Row-based allocation: fills left-to-right, moves to next row when full
- Allocation: `insert_bitmap()` handles placement, `grow_page()` expands height
- Pages: separate textures (sokol compatibility), dynamic growth from 1024→4096

**Renderer (renderer.v):**
- Glyph cache: 4096-entry LRU map keyed by (face XOR (index<<2|bin))
- Cache eviction: O(n) scan over cache_ages map to find oldest
- Load path: `get_or_load_glyph()` → `load_glyph()` → `insert_bitmap()` → commit
- GPU upload: `commit()` calls `image.update_pixel_data()` on dirty pages

**Context (context.v):**
- MetricsCache: 256-entry LRU for FreeType metrics (ascent/descent)
- Key: u64 face pointer XOR (size << 32)
- No shape plan cache currently

**Layout (layout.v):**
- Pango integration: calls `pango_layout_new()` → `pango_layout_get_iter()` → process
- No shape plan caching at HarfBuzz level
- Extracts runs/glyphs into V structs, discards PangoLayout

## Shelf Packing Integration

### Modified Components

**GlyphAtlas.insert_bitmap() (glyph_atlas.v:487-576):**
- Replace row-based logic with shelf allocator
- Current: advances cursor_x, wraps to next row when full
- New: track shelves with varying heights, pack into best-fit shelf

**AtlasPage struct (glyph_atlas.v:50-62):**
- Add shelf tracking fields
- Current: `cursor_x`, `cursor_y`, `row_height`
- New: `shelves []Shelf` where `Shelf { y, height, cursor_x, free_width }`

### New Data Structures

```v
struct Shelf {
mut:
    y          int  // Y position of shelf baseline
    height     int  // Fixed height for this shelf
    cursor_x   int  // Current X position for next glyph
    free_width int  // Remaining width in shelf
}

struct ShelfAllocator {
mut:
    shelves []Shelf  // Active shelves, sorted by Y
    page_width  int
    page_height int
}
```

### Integration Points

**Allocation path:** `insert_bitmap()` calls shelf allocator instead of inline row logic

**Best-height-fit heuristic:** find shelf where glyph height minimizes wasted vertical space

**Shelf creation:** when no shelf fits, create new shelf at `max(shelf.y+shelf.height)`

**Page growth:** still handled by `grow_page()`, shelves span full width

**Compatibility:** maintains same error returns, CachedGlyph output, reset behavior

### Algorithm Choice

WebRender's shelf allocator (etagere) uses **Shelf Best Height Fit**:
- Packs into shelf minimizing wasted vertical space
- Simple, fast, works best for similar-height items (glyphs)
- Guillotine better packing but slower (thousands of items)

VGlyph glyphs have similar heights per font size → shelf packing suitable.

**Confidence:** HIGH (verified with WebRender production use)

### Build Order

1. Extract shelf allocator into separate module `shelf_packer.v`
2. Add shelf fields to AtlasPage (maintains backward compatibility)
3. Replace `insert_bitmap()` logic with shelf allocator calls
4. Test with existing atlas tests (should pass with better utilization)

## Async Texture Updates Integration

### Modified Components

**Renderer.commit() (renderer.v:105-119):**
- Current: synchronous `image.update_pixel_data()` per dirty page
- New: queue updates, upload with PBO or non-blocking path

**GlyphAtlas.insert_bitmap() (glyph_atlas.v:487-576):**
- Marks pages dirty (no change)
- May need staging buffer instead of direct atlas data write

### New Data Structures

```v
struct PendingUpload {
    page_idx int
    staging_buffer []u8  // Copy of atlas data to upload
    ready bool           // Has rasterization completed?
}

struct Renderer {
mut:
    pending_uploads []PendingUpload
    staging_buffers [][]u8  // Pre-allocated buffers
}
```

### Integration Points

**Upload path:** `commit()` → queue PendingUpload → sokol async upload

**Sokol limitation:** sokol_gfx.h doesn't expose PBO or async upload directly

**Workaround options:**
1. Use sokol's update mechanism (still blocking)
2. Drop to raw OpenGL PBOs (breaks abstraction)
3. Double-buffer staging: rasterize to staging while GPU uploads previous

**Recommended:** Double-buffered staging (stays within sokol)

**Algorithm:**
- Rasterize glyphs to staging buffer A while GPU uploads buffer B
- Swap buffers when upload completes (fence or frame boundary)
- No actual async upload, but overlaps CPU/GPU work

**Confidence:** MEDIUM (sokol abstraction limits true async)

### Sokol Context

Sokol uses `sg.ImageDesc{usage: .dynamic}` for atlas textures:
- Dynamic images allow updates via `sg.update_image()`
- Update is synchronous within sokol abstraction
- Backend may use PBOs (OpenGL) or staging buffers (Metal/Vulkan) internally

**PBOs in OpenGL:**
- Use `glMapBuffer()` to get CPU-writable pointer
- Unmap triggers async DMA transfer to GPU
- Requires raw OpenGL calls (bypasses sokol)

**Staging strategy:**
- Pre-allocate staging buffers (page_width * page_height * 4)
- Rasterize to staging instead of atlas.image.data
- Swap staging buffers per frame
- Call `update_pixel_data()` from staging buffer

**Benefits:** CPU rasterization doesn't block on GPU upload completion

### Build Order

1. Add staging buffers to Renderer struct
2. Modify `insert_bitmap()` → rasterize to staging buffer
3. Modify `commit()` → swap staging buffers before upload
4. Benchmark: measure frame time reduction (expect 5-10% on glyph-heavy frames)

## Shape Plan Caching Integration

### Modified Components

**Context (context.v):**
- Add ShapePlanCache parallel to MetricsCache
- Cache plans per (font face, language, features) tuple

**Layout (layout.v):**
- Extract shape plan key before `layout_text()`
- Check cache, reuse plan if present
- Call `hb_shape_plan_create_cached()` instead of direct shaping

### New Data Structures

```v
struct ShapePlanKey {
    face voidptr       // FT_FaceRec pointer
    language string    // e.g., "en", "ja", "zh"
    features string    // Serialized OpenType features
}

struct ShapePlanCache {
mut:
    plans map[u64]voidptr  // ShapePlanKey hash → hb_shape_plan_t*
    access_order []u64     // LRU tracking
    capacity int = 128     // Max cached plans
}
```

### Integration Points

**Cache key:** hash of (face pointer, language string, features string)

**HarfBuzz integration:**
- Pango uses HarfBuzz internally (pango_layout_new → hb_shape)
- No direct HarfBuzz API in current VGlyph code
- Need to extract PangoFont → FT_Face → hb_face_t → hb_shape_plan

**Pango shaping path:**
1. `pango_layout_new()` creates layout
2. `pango_layout_get_iter()` → `pango_layout_iter_get_run_readonly()`
3. PangoLayoutRun contains `item.analysis.font` (PangoFont)
4. `pango_ft2_font_get_face()` → FT_FaceRec (already used)

**HarfBuzz caching:** `hb_shape_plan_create_cached()` maintains internal cache

**Problem:** Pango abstracts HarfBuzz, no direct access to shape plans

**Alternative:** Cache PangoLayout objects instead

### Pango Layout Caching Strategy

VGlyph already has LayoutCache (layout_query.v) with TTL-based eviction.

**Current LayoutCache:**
- Caches full Layout result (after shaping complete)
- Key: (text, style, block config)
- TTL: 5 second expiration

**Enhancement:** This already caches shaped results, so HarfBuzz shaping is avoided

**Shape plan caching benefit:** Minimal if LayoutCache hit rate is high

**Recommendation:** Monitor LayoutCache hit rate before adding HarfBuzz-level cache

### Build Order

1. Instrument LayoutCache hit/miss counters (profile builds)
2. Benchmark common use cases (text editor, UI labels)
3. If miss rate > 20%, consider direct HarfBuzz integration
4. Otherwise, existing LayoutCache sufficient

**Confidence:** LOW (Pango abstraction makes direct HB cache complex)

### HarfBuzz Recent Improvements

HarfBuzz 12.3 (2025):
- AAT shaping: 12% faster (LucidaGrande benchmark)
- OpenType shaping: 20% faster (NotoNastaliqUrdu) via Coverage caching

**Takeaway:** Upgrading HarfBuzz may provide gains without code changes

## Suggested Build Order

**Phase 1: Shelf Packing (HIGH confidence, immediate wins)**
1. Extract shelf allocator to `shelf_packer.v`
2. Add Shelf struct and allocator logic
3. Integrate into `insert_bitmap()`
4. Test with atlas_debug example
5. Measure atlas utilization improvement (expect 10-15% better)

**Phase 2: Async Texture Updates (MEDIUM confidence, measurable but limited)**
1. Add staging buffers to Renderer
2. Modify `insert_bitmap()` to rasterize to staging
3. Implement double-buffering in `commit()`
4. Benchmark frame time (expect 5-10% on heavy frames)
5. Consider if gains justify complexity (may defer)

**Phase 3: Shape Plan Caching (LOW confidence, validate first)**
1. Add LayoutCache hit/miss instrumentation
2. Run benchmarks (editor demo, stress demo)
3. If miss rate < 20%, skip this optimization
4. If miss rate high, explore direct HarfBuzz caching (complex)

**Rationale:** Shelf packing is low-risk, high-reward. Async uploads have sokol limits. Shape
caching may be redundant with existing LayoutCache.

## Data Flow Changes

### Current Flow

```
draw_layout() → get_or_load_glyph() → load_glyph() → ft_bitmap_to_bitmap()
    → insert_bitmap() [row-based] → copy_bitmap_to_page() → page.dirty = true
    → commit() [synchronous upload] → update_pixel_data()
```

### With Shelf Packing

```
insert_bitmap() → ShelfAllocator.allocate() [best-height-fit]
    → find_or_create_shelf() → pack into shelf → copy_bitmap_to_page()
```

**Change:** Allocation logic only, rest of pipeline unchanged

### With Async Uploads

```
insert_bitmap() → copy_bitmap_to_staging_buffer() → page.dirty = true
commit() → swap_staging_buffers() → update_pixel_data(staging_buffer)
    [CPU rasterizes to buffer A while GPU uploads buffer B]
```

**Change:** Rasterization target and upload source, GPU call unchanged

### With Shape Plan Caching

```
layout_text() → compute_cache_key() → check ShapePlanCache
    → if hit: reuse hb_shape_plan_t
    → if miss: hb_shape_plan_create_cached() → insert into cache
    → pango_layout_new() [may internally use cached plan]
```

**Change:** Pre-shaping cache lookup, Pango call may benefit from HarfBuzz cache

**Note:** Pango abstraction means indirect benefit only

## Integration Risks

**Shelf Packing:**
- Risk: Glyph placement order changes, may expose cache invalidation bugs
- Mitigation: Existing multi-page reset logic handles this
- Risk: Edge case where glyph fits in page but no shelf has space
- Mitigation: Create new shelf or fallback to page grow

**Async Uploads:**
- Risk: Sokol doesn't expose true async, may add complexity without benefit
- Mitigation: Profile before full implementation, consider deferring
- Risk: Staging buffer overhead (double memory for atlas)
- Mitigation: VGlyph atlas max is 4×4096×4096×4 = 256MB, staging adds 256MB

**Shape Plan Caching:**
- Risk: Pango abstraction prevents direct HarfBuzz cache control
- Mitigation: Use existing LayoutCache instead, instrument hit rate
- Risk: HarfBuzz internal cache may already optimize this
- Mitigation: Benchmark before implementing

## Performance Expectations

**Shelf Packing:**
- Atlas utilization: 60-70% → 80-85% (WebRender data)
- Allows more glyphs per page, fewer page resets
- No runtime cost increase (still O(n) shelf scan)

**Async Uploads:**
- Frame time: 5-10% reduction on glyph-heavy frames
- Benefit depends on rasterize/upload ratio
- Limited by sokol's synchronous API

**Shape Plan Caching:**
- Benefit unclear (LayoutCache may already cover this)
- HarfBuzz 12.3 improvements (20% faster OpenType) available via library upgrade
- Recommend: upgrade HarfBuzz first, then re-evaluate

## Dependencies

**Shelf Packing:**
- No external dependencies
- Pure algorithmic change
- Compatible with existing sokol/gg backend

**Async Uploads:**
- Sokol version: check if newer versions expose async upload
- OpenGL PBOs: requires raw GL calls (breaks abstraction)
- Metal staging: sokol may handle internally

**Shape Plan Caching:**
- HarfBuzz version: 4.4.0+ has improved caching (2023)
- Pango version: ensure HarfBuzz integration enabled
- FreeType: no changes needed

## Sources

- [Étagère: WebRender texture atlas allocation](https://nical.github.io/posts/etagere.html)
- [Skyline algorithm for 2D rectangle packing](https://jvernay.fr/en/blog/skyline-2d-packer/implementation/)
- [HarfBuzz shape plan caching](https://harfbuzz.github.io/shaping-plans-and-caching.html)
- [HarfBuzz 12.3 performance improvements](https://www.phoronix.com/news/HarfBuzz-12.3-Released)
- [OpenGL PBO async texture upload](https://www.songho.ca/opengl/gl_pbo.html)
- [Pango HarfBuzz integration](https://harfbuzz.github.io/integration.html)
- [Texture packing for fonts](https://straypixels.net/texture-packing-for-fonts/)
