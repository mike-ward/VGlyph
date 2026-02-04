# Stack Research: Performance Optimization (v1.6)

**Researched:** 2026-02-04
**Focus:** Stack additions for shelf packing, async GPU uploads, HarfBuzz shape caching

## Executive Summary

Three optimizations require minimal stack additions. Shelf packing needs algorithm
implementation in V (no dependencies). Async uploads achievable with double-buffered texture
data approach (no PBOs needed with sokol). Shape plan caching requires HarfBuzz C API
bindings (already have harfbuzz pkgconfig).

## 1. Shelf Packing Allocator

### Algorithm Choice: Shelf Best-Height-Fit

**What:** Divides atlas into horizontal shelves. Places glyphs on shelf minimizing wasted
vertical space.

**Why this algorithm:**
- Ideal for similar-height items (glyphs are)
- Supports deallocation (unlike guillotine/skyline)
- Simple implementation (~100 LOC)
- Proven: Firefox étagère, Mapbox shelf-pack

**Performance:**
- Mapbox shelf-pack: 1,610 ops/sec (single alloc)
- "Several orders of magnitude faster" than general bin packers
- Firefox chose this over maxrects for simplicity + deallocation

**References:**
- [Mapbox shelf-pack](https://github.com/mapbox/shelf-pack) - JavaScript reference impl
- [Firefox étagère](https://nical.github.io/posts/etagere.html) - Rust impl, rationale
- [Roomanna shelf algorithms](https://blog.roomanna.com/09-25-2015/binpacking-shelf)

### Implementation in V

**Approach:** Pure V implementation, no external dependencies.

**Data structure:**
```v
struct Shelf {
    y int           // Y position of shelf
    height int      // Shelf height (tallest item)
    cursor_x int    // Next insertion X
    width int       // Total width available
}

struct ShelfAllocator {
    shelves []Shelf
    width int
    height int
    cursor_y int    // Next shelf Y
}
```

**Algorithm:**
```
pack(glyph_w, glyph_h):
    1. Find shelf with best height fit (min waste, glyph_h <= shelf.height)
    2. If found: place at shelf.cursor_x, advance cursor
    3. If not: create new shelf at cursor_y with height=glyph_h
    4. Return (x, y, shelf_index)
```

**Integration:** Replace current row-based allocation in `insert_bitmap()`
(glyph_atlas.v:487). Shelf allocator wraps AtlasPage, adds `shelves []Shelf` field.

### Tradeoffs

**Pros:**
- Better space utilization than current row packer
- Fast allocation (O(n) scan of shelves, typically <10 shelves)
- Deallocation possible (track per-shelf occupancy)

**Cons:**
- Wastes space if glyph heights vary significantly (not an issue - glyphs cluster by font
size)
- Not optimal packing (but 3-5% wasted space acceptable for simplicity)

## 2. Async Texture Updates

### Approach: Double-Buffered Pixel Data

**What:** Maintain 2 pixel buffers per atlas page. While GPU reads buffer A, CPU writes to
buffer B. Swap each frame.

**Why NOT PBOs:**
- Sokol abstracts GL/Metal/D3D11 - no direct PBO access
- `sg_update_image()` already async-capable on Metal/D3D11 (driver-managed)
- GL backend: sokol uses staging buffer, equivalent to PBO behavior

**Implementation approach:**

```v
struct AtlasPage {
    image gg.Image
    // Double buffer for pixel data
    buffer_a []u8
    buffer_b []u8
    active_buffer int  // 0=A, 1=B
    dirty bool
}

// In rasterization (load_glyph):
inactive_buffer := if page.active_buffer == 0 { page.buffer_b } else { page.buffer_a }
copy_bitmap_to_buffer(inactive_buffer, bmp, x, y)
page.dirty = true

// In commit():
if page.dirty {
    page.active_buffer = 1 - page.active_buffer  // Swap
    active := if page.active_buffer == 0 { page.buffer_a } else { page.buffer_b }
    page.image.update_pixel_data(active)
    page.dirty = false
}
```

**Key insight:** Sokol's `sg_update_image()` already performs async DMA transfer on backends
that support it. Double-buffering pixel data ensures CPU never blocks waiting for GPU.

**References:**
- [Sokol sg_update_image](https://github.com/floooh/sokol/issues/567) - partial update
discussion
- [OpenGL PBO technique](https://www.songho.ca/opengl/gl_pbo.html) - conceptual parallel
- [Sokol update restrictions](https://floooh.github.io/2020/04/26/sokol-spring-2020-update.html)
- one update/frame/resource

### Performance Benefits

**Current (synchronous):**
```
rasterize glyph -> copy to atlas.data -> update_pixel_data() [blocks until GPU copy done]
```

**With double-buffering:**
```
Frame N: rasterize -> copy to buffer_b (CPU)
         GPU reads buffer_a (parallel)
Frame N+1: swap buffers, update_pixel_data(buffer_a)
```

**Expected:** 20-30% reduction in upload_time_ns (from profiling data). GPU copy overlaps
with next frame's rasterization.

### Integration Points

**Modify:**
- `AtlasPage` struct: add buffer_a/buffer_b fields (glyph_atlas.v:50)
- `new_atlas_page()`: allocate 2 buffers instead of image.data (glyph_atlas.v:107)
- `copy_bitmap_to_page()`: write to inactive buffer (glyph_atlas.v:672)
- `commit()`: swap + upload active buffer (renderer.v:105)

**Memory cost:** 2x pixel data per page. With 4 pages * 4096x4096 * 4 bytes * 2 = 512MB max
(up from 256MB). Acceptable for performance gain.

## 3. Shape Plan Caching

### HarfBuzz API Integration

**What:** Cache HarfBuzz `hb_shape_plan_t` structures keyed by
(font_face, size, script, features) to avoid rebuilding shaping decisions.

**Why:** Pango uses HarfBuzz internally. Pango doesn't expose shape plan caching, but
HarfBuzz API is already linked (pkgconfig harfbuzz in c_bindings.v:6).

**API:**
```c
hb_shape_plan_t* hb_shape_plan_create_cached(
    hb_face_t *face,
    const hb_segment_properties_t *props,
    const hb_feature_t *user_features,
    unsigned int num_user_features,
    const char * const *shaper_list
);
```

**Reference counting:**
```c
hb_shape_plan_reference(plan);   // Increment refcount
hb_shape_plan_destroy(plan);     // Decrement, free at 0
```

**References:**
- [HarfBuzz shape plan docs](https://harfbuzz.github.io/shaping-plans-and-caching.html)
- [hb-shape-plan API](https://harfbuzz.github.io/harfbuzz-hb-shape-plan.html)

### Implementation Strategy

**Problem:** Pango abstracts HarfBuzz. Can't intercept Pango's shaping to inject cached
plans.

**Solution:** Cache at Layout level, not shape plan level.

**Revised approach:**
```v
struct LayoutCache {
    entries map[u64]CachedLayout  // Existing
    shape_stats map[u64]ShapeStats  // NEW
}

struct ShapeStats {
    shaping_time_ns i64
    hit_count int
}

// Track per-layout shaping cost
layout_key := hash(text, font, width, ...)
if existing_layout := cache.get(layout_key) {
    // Cache hit - no shaping
    cache.shape_stats[layout_key].hit_count++
} else {
    // Cache miss - time the shaping
    start := time.sys_mono_now()
    layout := pango_layout_new(...)  // Pango does HarfBuzz shaping internally
    shaping_time := time.sys_mono_now() - start
    cache.shape_stats[layout_key] = ShapeStats{ shaping_time_ns: shaping_time, ... }
}
```

**Key insight:** Pango already has internal HarfBuzz caching. Our Layout cache (with TTL)
already provides shape plan reuse. Optimization is cache tuning, not HarfBuzz bindings.

### Cache Tuning

**Current:** Layout cache with 100ms TTL (layout.v, LayoutCache struct).

**Optimization:**
1. Increase TTL to 500ms (text doesn't change often)
2. Add cache size limit (evict LRU when >256 entries)
3. Track shape cost in profile metrics

**Expected benefit:** 40-60% reduction in layout_time_ns for repeated text (scrolling,
animation). Pango's internal HarfBuzz cache + our Layout cache = effective shape plan
caching.

### Alternative: Direct HarfBuzz Bindings

**If** profiling shows Pango caching insufficient:

**Add C bindings (c_bindings.v):**
```v
#pkgconfig harfbuzz  // Already present

struct C.hb_shape_plan_t {}
struct C.hb_face_t {}
struct C.hb_segment_properties_t {
    direction u32
    script u32
    language voidptr
}

fn C.hb_shape_plan_create_cached(face &C.hb_face_t, props &C.hb_segment_properties_t,
    user_features voidptr, num_features u32, shaper_list &char) &C.hb_shape_plan_t
fn C.hb_shape_plan_reference(plan &C.hb_shape_plan_t) &C.hb_shape_plan_t
fn C.hb_shape_plan_destroy(plan &C.hb_shape_plan_t)
```

**Cache structure:**
```v
struct ShapePlanCache {
    plans map[u64]&C.hb_shape_plan_t
    access_order []u64
    capacity int = 128
}
```

**Integration:** Extract `hb_face_t` from `PangoFont` via Pango-FT2 API, cache plans keyed
by (face_ptr XOR size XOR script). Use in custom shaping path if needed.

**Defer until:** Phase profiling shows layout_time_ns remains bottleneck after Layout cache
tuning.

## Integration Summary

### Existing Stack (No Changes)

| Component | Version | Purpose |
|-----------|---------|---------|
| Pango | System | Text layout, shaping orchestration |
| HarfBuzz | System (via Pango) | Complex text shaping |
| FreeType | System | Glyph rasterization |
| Sokol/gg | V stdlib | GPU abstraction (GL/Metal/D3D11) |

### New Code (Pure V)

| Component | LOC Est. | Purpose |
|-----------|----------|---------|
| ShelfAllocator | ~120 | Shelf packing algorithm |
| Double-buffered pages | ~50 | Async texture data management |
| Layout cache tuning | ~30 | TTL increase, LRU eviction, metrics |

**Total new code:** ~200 LOC, no dependencies.

## What NOT to Add

### ❌ Pixel Buffer Objects (PBOs)

**Why not:** Sokol abstracts GL - no direct PBO access. Double-buffered pixel data achieves
same async benefit without GL-specific code.

**Alternative:** Double-buffered pixel data (cross-platform, simpler).

### ❌ External Bin Packing Library

**Why not:**
- Existing options are JS (mapbox/shelf-pack) or Rust (étagère)
- V-to-C wrapper overhead
- Algorithm is simple (~100 LOC in V)

**Alternative:** Implement shelf packing directly in V.

### ❌ HarfBuzz Direct Bindings (Initially)

**Why not:** Pango already uses HarfBuzz internally. Layout cache provides equivalent shape
plan reuse. Premature optimization.

**Defer until:** Profiling proves Pango caching insufficient (unlikely).

### ❌ Compute Shaders for Rasterization

**Why not:**
- FreeType already fast (GPU rasterization complex for quality/hinting)
- Upload bottleneck is bandwidth, not rasterization
- Adds GL 4.3+ / Metal requirement

**Alternative:** Async uploads solve bandwidth issue.

## Risk Assessment

| Change | Risk | Mitigation |
|--------|------|------------|
| Shelf packing | Incorrect allocation, overlaps | Unit tests with visual atlas dump |
| Double-buffering | Race if buffers swapped mid-rasterize | Single-threaded V, clear swap point |
| Memory increase (2x buffers) | 512MB max vs 256MB current | Document, acceptable for performance |
| Layout cache tuning | Stale text with long TTL | 500ms reasonable for UI responsiveness |

**Overall risk:** Low. Pure V code, no new dependencies, incremental changes.

## Verification Strategy

### Shelf Packing

**Unit test:**
```v
fn test_shelf_allocator() {
    mut alloc := new_shelf_allocator(1024, 1024)
    // Pack 100 glyphs, verify no overlaps
    for i in 0..100 {
        rect := alloc.pack(32, 32)!
        assert rect.x + 32 <= 1024
        assert rect.y + 32 <= 1024
    }
}
```

**Visual:** atlas_debug.v example - render shelf boundaries, check packing density.

### Async Uploads

**Profile metric:** Compare `upload_time_ns` before/after with `-d profile`.

**Stress test:** stress_demo.v - rapidly add/remove text, verify no visual corruption.

### Shape Plan Caching

**Profile metric:** Compare `layout_time_ns` hit rate before/after cache tuning.

**Benchmark:** Repeated layout_text() calls with identical params, measure speedup.

## Sources

**Shelf Packing:**
- [Mapbox shelf-pack](https://github.com/mapbox/shelf-pack)
- [Firefox étagère rationale](https://nical.github.io/posts/etagere.html)
- [Shelf algorithms explained](https://blog.roomanna.com/09-25-2015/binpacking-shelf)
- [Texture packing lisyarus](https://lisyarus.github.io/blog/posts/texture-packing.html)

**Async Uploads:**
- [Sokol sg_update_image discussion](https://github.com/floooh/sokol/issues/567)
- [OpenGL PBO technique](https://www.songho.ca/opengl/gl_pbo.html)
- [Sokol spring 2020 update](https://floooh.github.io/2020/04/26/sokol-spring-2020-update.html)
- [V gg.Image implementation](https://github.com/vlang/v/blob/master/vlib/gg/image.c.v)

**HarfBuzz:**
- [HarfBuzz shape plan caching](https://harfbuzz.github.io/shaping-plans-and-caching.html)
- [hb-shape-plan API](https://harfbuzz.github.io/harfbuzz-hb-shape-plan.html)
