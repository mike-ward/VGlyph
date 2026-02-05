# Phase 27: Async Texture Updates - Research

**Researched:** 2026-02-05
**Domain:** Metal texture upload optimization via double-buffered staging
**Confidence:** HIGH

## Summary

Phase 27 adds double-buffered pixel staging to overlap CPU rasterization with GPU texture uploads.
Current implementation uses synchronous `replaceRegion` at commit time, blocking CPU until copy
completes. Standard approach: allocate two staging buffers per atlas page (front/back), write
to back buffer during rasterization, swap at commit, upload from front while CPU writes to back.

Context decisions constrain design: 2 buffers per page (not shared pool), both allocated upfront,
kill switch for debug/fallback. Key tradeoff: buffer swap timing affects memory visibility and
sync complexity.

**Primary recommendation:** Swap at commit time (not draw time) to preserve existing semantics
where commit() → draw() ordering guarantees visible glyphs.

## Standard Stack

Metal provides built-in texture upload mechanisms without external dependencies.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Metal | macOS 10.11+ | Native GPU API | Apple's official graphics API |
| MTLTexture.replaceRegion | Core API | Texture upload | Standard sync upload method |
| MTLCommandBuffer | Core API | GPU command submission | Async operation coordination |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| Sokol-gfx | Current | Cross-platform abstraction | Already used, dynamic texture support |
| dispatch_semaphore | macOS Core | CPU/GPU sync | Triple-buffering backpressure pattern |
| MTLEvent | macOS 10.14+ | Cross-buffer sync | If untracked resources needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Per-page buffers | Shared buffer pool | Pool adds allocation complexity, per-page simpler |
| Double buffer | Triple buffer | Triple adds latency, double sufficient for atlas |
| replaceRegion | MTLBlitEncoder | Blit requires command buffer, overkill for CPU→GPU |

**Installation:**
No external dependencies — Metal/Sokol already present.

## Architecture Patterns

### Recommended Project Structure
```
glyph_atlas.v
├── AtlasPage
│   ├── image (current gg.Image)
│   ├── staging_front []u8  # GPU reads from this
│   ├── staging_back []u8   # CPU writes to this
│   └── dirty bool
```

### Pattern 1: Double-Buffered Staging Per Page
**What:** Each atlas page owns two staging buffers, swapped at commit time.
**When to use:** Dynamic textures updated per-frame with CPU writes.
**Example:**
```v
struct AtlasPage {
mut:
    image         gg.Image
    staging_front []u8  // GPU upload source (read-only during upload)
    staging_back  []u8  // CPU rasterization target (write-only during frame)
    dirty         bool
    // ... existing fields
}

// During copy_bitmap_to_page():
copy_to_buffer(mut page.staging_back, bmp, x, y)
page.dirty = true

// At commit() time:
if page.dirty {
    page.swap_staging_buffers()
    page.image.update_pixel_data(page.staging_front)
    page.dirty = false
}
```

### Pattern 2: Commit-Time Swap
**What:** Swap front/back buffers at commit(), upload front buffer.
**When to use:** Preserve commit() → draw() visibility semantics.
**Why:** CPU rasterizes into back buffer during frame, swap makes writes visible to GPU,
upload proceeds while next frame's rasterization starts.

### Pattern 3: Kill Switch for Fallback
**What:** Runtime flag to disable async, force synchronous uploads.
**When to use:** Debugging corruption, compatibility fallback.
**Example:**
```v
pub struct GlyphAtlas {
    // ... existing fields
    async_uploads bool = true  // Kill switch
}

fn (mut atlas GlyphAtlas) commit() {
    if !atlas.async_uploads {
        // Synchronous path: write directly to image.data
        return
    }
    // Async path: swap staging buffers
}
```

### Anti-Patterns to Avoid
- **Shared staging pool:** Adds allocation complexity, per-page ownership simpler
- **Draw-time swap:** Breaks commit() → draw() visibility, requires complex dirty tracking
- **Lazy buffer allocation:** Unpredictable memory spikes, allocate upfront per context decision

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GPU sync wait | Custom semaphore | dispatch_semaphore | Apple's proven triple-buffer pattern |
| Cross-buffer sync | Manual fences | MTLEvent (if needed) | Proper cross-command-buffer ordering |
| Texture lifecycle | Manual tracking | MTLCommandBuffer completion handler | Guaranteed after GPU finishes |
| Upload profiling | Custom timers | `$if profile ?` with sys_mono_now | Existing pattern in renderer.v |

**Key insight:** Metal's `replaceRegion` already handles async CPU→GPU copy on macOS.
Double-buffering prevents overwriting data mid-upload, not making upload async (already is).

## Common Pitfalls

### Pitfall 1: Overwriting Back Buffer Before Upload Completes
**What goes wrong:** CPU writes to back buffer, swap happens, CPU immediately writes to
new back buffer (old front) before GPU finishes reading it.
**Why it happens:** No backpressure mechanism when CPU outpaces GPU.
**How to avoid:** Track in-flight uploads per page. If front buffer still uploading, defer
swap or stall CPU (use semaphore pattern if needed).
**Warning signs:** Visual corruption (torn glyphs), flicker, glyphs from wrong frame.

### Pitfall 2: Breaking commit() → draw() Ordering
**What goes wrong:** draw() called before commit(), sees stale atlas data.
**Why it happens:** Swapping at draw-time instead of commit-time.
**How to avoid:** Swap at commit() as per Pattern 2. Makes rasterized glyphs visible before
any draw() call in same frame.
**Warning signs:** Missing glyphs, one-frame delay before glyphs appear.

### Pitfall 3: Forgetting didModifyRange on Managed Textures (macOS)
**What goes wrong:** GPU sees stale texture data despite CPU upload.
**Why it happens:** Managed storage mode requires explicit CPU→GPU sync notification.
**How to avoid:** After replaceRegion on managed texture, call didModifyRange (or rely on
replaceRegion doing this automatically, which it does per Metal docs).
**Warning signs:** Glyphs don't update, or update delayed until unrelated GPU write.

### Pitfall 4: Upload Time Profiling Misattribution
**What goes wrong:** upload_time_ns measures CPU copy time, not GPU upload latency.
**Why it happens:** sys_mono_now() measures wall-clock, replaceRegion returns after CPU copy.
**How to avoid:** Accept that upload_time_ns measures CPU-side work. For true GPU timing,
need MTLCommandBuffer completion handlers (out of scope for -d profile).
**Warning signs:** upload_time_ns seems too fast, doesn't correlate with GPU load.

### Pitfall 5: Pixel Alignment Issues with RGB/BGR
**What goes wrong:** Diagonal artifacts or crashes during upload.
**Why it happens:** Row alignment not multiple of 4.
**How to avoid:** Atlas uses RGBA (4 channels), naturally 4-byte aligned. Non-issue for this
project.
**Warning signs:** Crashes in copy_bitmap_to_page, visual corruption.

## Code Examples

Verified patterns from research:

### Double-Buffer Allocation (Upfront)
```v
// Source: Context decision + Sokol pattern
fn new_atlas_page(mut ctx gg.Context, w int, h int) !AtlasPage {
    size := check_allocation_size(w, h, 4, 'new_atlas_page')!

    // Main image buffer (GPU texture backing)
    img.data = unsafe { vcalloc(int(size)) }

    // Staging buffers (per context decision: allocate both upfront)
    staging_front := []u8{len: int(size), init: 0}
    staging_back := []u8{len: int(size), init: 0}

    return AtlasPage{
        image: img
        staging_front: staging_front
        staging_back: staging_back
        // ... existing fields
    }
}
```

### Staging Buffer Swap at Commit
```v
// Source: Apple triple-buffering pattern adapted for double-buffer
pub fn (mut page AtlasPage) swap_staging_buffers() {
    // Pointer swap (no data copy)
    tmp := page.staging_front
    page.staging_front = page.staging_back
    page.staging_back = tmp
}

pub fn (mut renderer Renderer) commit() {
    for mut page in renderer.atlas.pages {
        if page.dirty {
            page.swap_staging_buffers()
            page.image.update_pixel_data(page.staging_front)
            page.dirty = false
        }
    }
}
```

### Copy to Staging Buffer (Not Main Image)
```v
// Source: Modified copy_bitmap_to_page pattern
fn copy_bitmap_to_staging(mut page AtlasPage, bmp Bitmap, x int, y int) ! {
    // Bounds validation (same as existing)
    if x < 0 || y < 0 || x + bmp.width > page.width || y + bmp.height > page.height {
        return error('bitmap copy out of bounds')
    }

    row_bytes := usize(bmp.width * 4)
    for row in 0 .. bmp.height {
        unsafe {
            src_ptr := &u8(bmp.data.data) + (row * bmp.width * 4)
            // Write to BACK buffer (CPU target)
            dst_ptr := &u8(page.staging_back.data) + ((y + row) * page.width + x) * 4
            vmemcpy(dst_ptr, src_ptr, row_bytes)
        }
    }
}
```

### Kill Switch Implementation
```v
// Source: Context decision for debug/fallback
pub struct GlyphAtlas {
    // ... existing fields
    async_uploads bool = true  // Default enabled, set false to disable
}

pub fn (mut renderer Renderer) commit() {
    if !renderer.atlas.async_uploads {
        // Synchronous fallback: copy directly to image.data (existing behavior)
        for mut page in renderer.atlas.pages {
            if page.dirty {
                // Copy from staging_back to image.data
                unsafe { vmemcpy(page.image.data, page.staging_back.data, page.staging_back.len) }
                page.image.update_pixel_data(page.image.data)
                page.dirty = false
            }
        }
        return
    }

    // Async path: swap and upload from front
    for mut page in renderer.atlas.pages {
        if page.dirty {
            page.swap_staging_buffers()
            page.image.update_pixel_data(page.staging_front)
            page.dirty = false
        }
    }
}
```

### Upload Time Profiling
```v
// Source: Existing $if profile pattern in renderer.v
pub fn (mut renderer Renderer) commit() {
    $if profile ? {
        start := time.sys_mono_now()
        defer {
            renderer.upload_time_ns += time.sys_mono_now() - start
        }
    }
    // ... commit logic
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Direct image.data write | Staging buffers | 2015+ (PBO era) | CPU/GPU overlap possible |
| Single buffer | Double/triple buffer | 2010s | Prevents overwrite-during-read |
| MTLFence | MTLEvent | macOS 10.14 | Cross-buffer sync support |
| Managed mode only | Private+Blit pattern | ~2016 | Better perf on discrete GPU |

**Deprecated/outdated:**
- Managed storage for GPU-only textures (use Private + blit from Shared staging)
- Single buffer dynamic updates (always double-buffer minimum)
- replaceRegion blocking assumption (async on macOS since Metal introduction)

## Open Questions

Things that couldn't be fully resolved:

1. **Sokol's update_pixel_data internal behavior**
   - What we know: Calls Metal replaceRegion under hood (per Sokol backend tour)
   - What's unclear: Whether Sokol adds extra synchronization or buffering
   - Recommendation: Assume direct replaceRegion behavior, verify with profiling

2. **Backpressure mechanism necessity**
   - What we know: Triple-buffering uses semaphore to prevent CPU racing ahead
   - What's unclear: Whether atlas updates (infrequent, bounded) need this
   - Recommendation: Start without semaphore, add if corruption observed

3. **Per-region dirty tracking value**
   - What we know: Current code has per-page dirty bool
   - What's unclear: Whether tracking dirty regions (not whole page) worth complexity
   - Recommendation: Start with per-page (simpler), profile to see if upload time issue

4. **Memory overhead acceptable threshold**
   - What we know: 2 staging buffers per page = 2x current atlas memory
   - What's unclear: Whether 4 pages × 4096×4096×4 × 2 = ~512MB acceptable
   - Recommendation: Document in phase plan, measure in practice

## Sources

### Primary (HIGH confidence)
- [Apple Metal Best Practices: Resource Options](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/ResourceOptions.html)
- [Apple Metal Best Practices: Triple Buffering](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/TripleBuffering.html)
- [Sokol Metal Backend Tour](https://floooh.github.io/2020/02/20/sokol-gfx-backend-tour-metal.html)
- [MTLTexture replaceRegion documentation](https://developer.apple.com/documentation/metal/mtltexture/1515679-replaceregion)

### Secondary (MEDIUM confidence)
- [Oryol Metal Renderer Tour](https://floooh.github.io/2016/01/15/oryol-metal-tour.html) - Verified with Sokol docs
- [Metal API thread safety](https://developer.apple.com/forums/thread/93346) - Official forum
- [GPU Synchronisation discussion](https://developer.apple.com/forums/thread/110024) - Official forum

### Tertiary (LOW confidence)
- [OpenGL PBO tutorial](https://www.songho.ca/opengl/gl_pbo.html) - Cross-API pattern validation
- [Vulkan staging buffer tutorial](https://vulkan-tutorial.com/Vertex_buffers/Staging_buffer) - Pattern comparison

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Metal APIs documented, Sokol usage verified in codebase
- Architecture: HIGH - Apple triple-buffering pattern well-established, adapted for double
- Pitfalls: MEDIUM - Common issues from cross-API research, Metal-specific verified
- Code examples: HIGH - Based on existing glyph_atlas.v patterns + Apple docs

**Research date:** 2026-02-05
**Valid until:** 60 days (Metal APIs stable, Sokol patterns mature)
