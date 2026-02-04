# Features Research: Performance Optimization

**Project:** VGlyph v1.6
**Researched:** 2026-02-04
**Confidence:** MEDIUM

## Executive Summary

Performance optimizations for text rendering focus on three areas: efficient atlas allocation
(shelf packing), non-blocking GPU uploads (async texture updates), and shaping computation
reduction (shape plan caching). VGlyph already has multi-page atlas with LRU eviction,
glyph/metrics caches, and profiling instrumentation — optimizations build on this foundation.

## Shelf Packing Allocator

Efficient bin allocation reducing wasted atlas space vs current allocator.

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Horizontal shelf allocation | Industry standard, best for glyph sizes | Medium | Simple > guillotine for glyphs |
| Best-fit or first-fit heuristic | Minimize vertical waste | Low | Best-fit preferred for glyphs |
| Shelf merging on deallocation | Prevent vertical fragmentation | Medium | Critical for long sessions |
| Configurable shelf alignment | Platform texture requirements | Low | 4-byte alignment typical |

**Sources:**
- [WebRender etagere](https://nical.github.io/posts/etagere.html) — simple shelf allocator,
  2-column split on 2048x2048, satisfying compromise
- [Skyline algorithm](https://jvernay.fr/en/blog/skyline-2d-packer/implementation/) — O(N^2)
  where N is skyline points (typically low)
- [Shelf algorithms comparison](https://blog.roomanna.com/09-25-2015/binpacking-shelf) —
  first-fit vs best-area vs worst-width

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Two-column split per page | 2x reduction in shelf scan | Medium | WebRender validated on 2048x2048 |
| Waste factor tracking | Profiling visibility | Low | Integrate with existing `-d profile` |
| Bucketed shelf variant | Faster alloc/dealloc via ref-counted buckets | High | Trades memory for CPU |

**Sources:**
- [WebRender performance](https://nical.github.io/posts/etagere.html) — two columns optimal for
  2048x2048
- [Bin packing fragmentation](https://www.gamedev.net/forums/topic/568749-bin-packing-texture-atlasing-glyph-caching-how-do-you-do-it/) —
  waste tracking valuable for tuning

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Guillotine packing | Complexity without glyph-specific benefit | Use shelf (simpler, sufficient) |
| Runtime defragmentation | Texture re-upload overhead, frame stalls | Prefer shelf merging on deallocation |
| Skyline per-pixel tracking | Memory overhead for marginal improvement | Use shelf with coarser granularity |
| Variable page sizes | Complicates management, unclear benefit | Stick with uniform 2048x2048 pages |

**Sources:**
- [WebRender decision](https://nical.github.io/posts/etagere.html) — simple shelf beat guillotine
- [Defragmentation cost](https://github.com/nical/guillotiere) — coalescing needed but full
  defrag avoided
- [Texture atlas fragmentation](https://github.com/maggio-a/texture-defrag) — defrag for
  photo-reconstruction, not dynamic text

## Async Texture Updates

Non-blocking GPU uploads during glyph rasterization.

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Pixel Buffer Objects (PBOs) | OpenGL standard for async upload | Medium | GL_PIXEL_UNPACK_BUFFER target |
| Double-buffered PBOs | Overlap CPU write with GPU read | Medium | Write to PBO[1] while GPU reads PBO[0] |
| glMapBuffer for writes | Standard async upload pattern | Low | Map, write, unmap, glTexSubImage2D |
| Immediate return on upload | No frame stall during texture transfer | Medium | Core async benefit |

**Sources:**
- [OpenGL PBO tutorial](https://www.songho.ca/opengl/gl_pbo.html) — double-buffering enables
  simultaneous CPU write and GPU DMA
- [Buffer streaming wiki](https://wikis.khronos.org/opengl/Buffer_Object_Streaming) — multiple
  buffers avoid implicit sync
- [Async texture upload Unity](https://docs.unity3d.com/2019.3/Documentation/Manual/AsyncTextureUpload.html) —
  time-sliced upload reduces main thread wait

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Buffer orphaning fallback | Single-buffer alternative to double-PBO | Low | glBufferData(NULL) re-allocates |
| Upload batching per frame | Multiple glyphs per PBO transfer | Medium | Reduce API call overhead |
| Profiling: upload time | Visibility into async benefit | Low | Add to existing `-d profile` |
| Persistent mapping (GL 4.4+) | Eliminate map/unmap overhead | High | Requires fence sync, coherent flags |

**Sources:**
- [Buffer orphaning](https://handmade.network/forums/t/6990-buffer_orphaning_in_opengl) —
  simpler than double-PBO, implementation-dependent
- [Persistent buffers](https://community.khronos.org/t/can-persistently-mapped-buffers-be-used-for-texture-upload/75228) —
  GL 4.4+, eliminates unmap overhead

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Synchronous glTexSubImage2D | Blocks CPU on GPU transfer | Use PBOs for async DMA |
| Single PBO without orphaning | Implicit sync stalls pipeline | Double-buffer or orphan |
| glGetTexImage for readback | Irrelevant to upload, major stall | Never needed for glyph rendering |
| Compressed texture formats | Text quality loss, decoder overhead | Use uncompressed RGBA/grayscale |

**Sources:**
- [Frame budget](https://news.ycombinator.com/item?id=6574951) — 16ms for 60fps, 8ms for 120fps;
  stalls eat budget
- [GPU texture upload stall](https://developer.nvidia.com/gpugems/gpugems/part-v-performance-and-practicalities/chapter-28-graphics-pipeline-performance) —
  large texture uploads cause frame drops

## Shape Plan Caching

HarfBuzz shaping optimization for repeated text with same font/script/language.

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| hb_shape_plan_create_cached | HarfBuzz builtin caching API | Low | Uses face, props, features, shapers |
| Cache key: face + script + lang | Minimum key for shape plan reuse | Low | HarfBuzz manages internally |
| Reference counting | HarfBuzz automatic lifecycle | Low | hb_shape_plan_reference/destroy |
| User features in key | Font features affect shaping | Low | Part of create_cached signature |

**Sources:**
- [HarfBuzz shape plans](https://harfbuzz.github.io/shaping-plans-and-caching.html) — caching
  valuable when resources tight
- [Shape plan API](https://harfbuzz.github.io/harfbuzz-hb-shape-plan.html) — create_cached with
  face, props, features

### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| hb_shape_plan_create_cached2 | Variable font support (variation coords) | Low | HarfBuzz 2.6.7+ |
| Profiling: plan cache hits | Visibility into reuse | Low | Add to existing `-d profile` |
| Explicit plan reuse | Manual lifecycle for hot paths | Medium | Create once, reuse for batch |
| Plan warm-up on font load | Precompute common script/lang pairs | Medium | Avoid first-frame cost |

**Sources:**
- [HarfBuzz cached2](https://www.manpagez.com/html/harfbuzz/harfbuzz-2.6.7/harfbuzz-hb-shape-plan.php) —
  variation-space coords for variable fonts
- [Shape plan internals](https://harfbuzz.github.io/shaping-and-shape-plans.html) — script/lang
  lookups, fallback decisions, buggy font workarounds

### Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Application-level plan caching | HarfBuzz already does this | Use hb_shape_plan_create_cached |
| Caching shaped output | Layout cache already exists (VGlyph v1.2) | Cache plans, not results |
| Font hashing for cache key | Overcomplicated vs face pointer | Use HarfBuzz face object directly |
| Per-glyph plan creation | Massive overhead, defeats purpose | Plan per text segment (paragraph) |

**Sources:**
- [Existing VGlyph layout cache](PROJECT.md:22) — TTL-based, caches shaped results
- [Shape plan rationale](https://harfbuzz.github.io/shaping-plans-and-caching.html) — avoid
  "decision-making and trade-offs" overhead

## Feature Dependencies

### On Existing VGlyph Features

| Optimization | Depends On | How |
|--------------|------------|-----|
| Shelf packing | Multi-page atlas (v1.2) | Allocator operates within pages |
| Shelf packing | LRU page eviction (v1.2) | Eviction triggers when shelf alloc fails |
| Shelf packing | Profiling infrastructure (v1.2) | Waste factor tracking via `-d profile` |
| Async texture | OpenGL context (existing) | PBOs require GL context |
| Async texture | Glyph rasterization (existing) | FreeType bitmap → PBO → texture |
| Async texture | Profiling infrastructure (v1.2) | Upload time tracking via `-d profile` |
| Shape plan cache | Pango/HarfBuzz (existing) | HarfBuzz provides caching API |
| Shape plan cache | Layout cache (v1.2) | Plan cache sits before layout cache |
| Shape plan cache | Profiling infrastructure (v1.2) | Cache hit tracking via `-d profile` |

### Internal Dependencies

| Feature | Depends On | Why |
|---------|------------|-----|
| Shelf waste tracking | Shelf allocator | Can't track waste without allocator |
| Upload batching | PBOs | Batching requires async upload mechanism |
| Plan cache hit tracking | Shape plan caching | Can't track what doesn't exist |

## MVP Recommendation

**For v1.6 MVP, prioritize:**

1. **Shelf packing allocator** (simple variant, 2-column)
   - Biggest visible impact: reduced atlas waste
   - Complexity: medium, well-understood algorithm
   - Integrates cleanly with existing multi-page atlas

2. **Async texture updates** (double-PBO)
   - Eliminates frame stalls during glyph rasterization
   - Complexity: medium, standard OpenGL pattern
   - Measurable via existing profiling infrastructure

3. **Shape plan caching** (hb_shape_plan_create_cached)
   - Low complexity: one API call change
   - Immediate benefit for repeated text
   - HarfBuzz manages lifecycle automatically

**Defer to post-MVP:**
- Bucketed shelf variant: optimization of optimization, unnecessary complexity
- Persistent buffer mapping: requires GL 4.4+, fence sync adds complexity
- Plan warm-up: micro-optimization, first-frame cost negligible
- Upload batching: requires additional buffering logic, marginal gain over double-PBO

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Shelf packing | HIGH | WebRender production use, freetype-gl reference, clear algorithm |
| Async texture | MEDIUM | Standard OpenGL pattern, verified via multiple sources, driver-dependent |
| Shape plan cache | HIGH | Official HarfBuzz API, clear documentation, reference-counted lifecycle |
| Performance impact | LOW | No benchmarks run, impact depends on workload characteristics |

## Open Questions

- Current atlas allocator: simple linear? row-based? (affects shelf packing integration)
- OpenGL version target: 3.3? 4.x? (affects PBO features available)
- Typical glyph size distribution: affects shelf allocator heuristic choice
- Font switching frequency: affects shape plan cache hit rate

## Sources Summary

**HIGH confidence (Context7/official docs):**
- [HarfBuzz Manual: Shape Plans](https://harfbuzz.github.io/shaping-plans-and-caching.html)
- [OpenGL Wiki: Buffer Streaming](https://wikis.khronos.org/opengl/Buffer_Object_Streaming)
- [OpenGL PBO Tutorial](https://www.songho.ca/opengl/gl_pbo.html)

**MEDIUM confidence (verified production implementations):**
- [WebRender Texture Atlas](https://nical.github.io/posts/etagere.html)
- [freetype-gl Skyline Packer](https://github.com/rougier/freetype-gl/blob/master/texture-atlas.h)

**LOW confidence (community discussions, unverified):**
- [GameDev.net bin packing discussion](https://www.gamedev.net/forums/topic/568749-bin-packing-texture-atlasing-glyph-caching-how-do-you-do-it/)
- [Handmade Network buffer orphaning](https://handmade.network/forums/t/6990-buffer_orphaning_in_opengl)
