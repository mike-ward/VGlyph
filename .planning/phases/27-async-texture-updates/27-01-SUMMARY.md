---
phase: 27-async-texture-updates
plan: 01
subsystem: rendering
tags: [async, texture-upload, double-buffer, gpu, performance]

# Dependency graph
requires:
  - phase: 26-shelf-packing
    provides: Atlas page structure with shelves
provides:
  - Double-buffered pixel staging (front/back per page)
  - Async texture upload path with CPU/GPU overlap
  - Sync fallback kill switch (async_uploads flag)
  - Upload profiling infrastructure
affects:
  - 28-gpu-metrics (will read upload_time_ns from this infrastructure)
  - 29-perf-validation (uses async_uploads to benchmark async vs sync)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Double-buffered staging (CPU writes to back, GPU reads from front)"
    - "Kill switch pattern for perf optimizations (async_uploads bool)"

key-files:
  created: []
  modified:
    - glyph_atlas.v
    - renderer.v

key-decisions:
  - "Upfront staging buffer allocation (at page creation, not lazy)"
  - "Preserve staging_back during grow_page (in-progress rasterization)"
  - "Zero both buffers in reset_page (prevents stale data)"
  - "Profile timing wraps entire commit() (measures CPU-side upload work)"

patterns-established:
  - "Staging buffer lifecycle: allocate upfront, preserve back during grow, zero on reset"
  - "Async commit pattern: swap then upload from front"
  - "Sync fallback pattern: copy back to image.data then upload"

# Metrics
duration: 3min
completed: 2026-02-05
---

# Phase 27 Plan 01: Async Texture Updates Summary

**Double-buffered pixel staging enables CPU rasterization to overlap with GPU texture upload**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-05T14:08:25Z
- **Completed:** 2026-02-05T14:11:10Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- AtlasPage has staging_front/staging_back buffers allocated per page
- CPU writes glyphs to staging_back during rasterization
- commit() swaps buffers and uploads from staging_front
- Kill switch (async_uploads=false) forces synchronous fallback
- Upload profiling measures CPU-side commit work via upload_time_ns

## Task Commits

Each task was committed atomically:

1. **Task 1: Add staging buffers to AtlasPage** - `9febd3d` (feat)
2. **Task 2: Async commit with swap+upload, sync fallback** - `2a63170` (feat)

## Files Created/Modified
- `glyph_atlas.v` - Added staging_front/staging_back to AtlasPage, async_uploads kill switch to GlyphAtlas, swap_staging_buffers method, staging buffer handling in new_atlas_page/reset_page/grow_page, rerouted copy_bitmap_to_page to write to staging_back
- `renderer.v` - Async commit path (swap then upload from front), sync fallback path (copy back to image.data then upload), kill switch check

## Decisions Made

1. **Upfront allocation:** Staging buffers allocated in new_atlas_page alongside image.data (not lazy) - simplifies lifecycle, prevents mid-frame allocation stalls
2. **Preserve staging_back during grow:** grow_page copies old staging_back to new staging_back - preserves in-progress rasterization during atlas expansion
3. **Zero both buffers on reset:** reset_page zeros staging_front and staging_back - prevents visual artifacts from stale data when page is reused
4. **Profile timing wraps commit:** $if profile block wraps entire commit() - measures CPU-side upload work for both async and sync paths

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Staging infrastructure complete
- Upload profiling operational via existing upload_time_ns field
- Ready for GPU metrics collection (Phase 28)
- async_uploads kill switch ready for perf benchmarking (Phase 29)

---
*Phase: 27-async-texture-updates*
*Completed: 2026-02-05*
