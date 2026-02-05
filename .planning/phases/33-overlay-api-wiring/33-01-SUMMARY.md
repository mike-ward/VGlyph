---
phase: 33-overlay-api-wiring
plan: 01
subsystem: api
tags: [objective-c, mtkview, ime, overlay, auto-discovery]

# Dependency graph
requires:
  - phase: 18-ime-overlay-foundation
    provides: "VGlyphIMEOverlayView with NSTextInputClient protocol"
  - phase: 19-ime-overlay-completion
    provides: "Full IME callback infrastructure"
provides:
  - "MTKView auto-discovery from NSWindow via view hierarchy walk"
  - "vglyph_create_ime_overlay_auto C API and V wrapper"
  - "Hard error pattern (NULL return) when MTKView not found"
affects: [IME-01-editor-demo-overlay, IME-02-callback-refactor, IME-06-multifield]

# Tech tracking
tech-stack:
  added: []
  patterns: ["View hierarchy traversal with depth limit", "Hard error on missing deps"]

key-files:
  created: []
  modified:
    - ime_overlay_darwin.h
    - ime_overlay_darwin.m
    - ime_overlay_stub.c
    - c_bindings.v

key-decisions:
  - "MTKView discovery via recursive findViewByClass with depth limit 100"
  - "Hard error (NULL return) when MTKView not found - no silent fallback"
  - "All parameters void* in public API - no macOS types leak"

patterns-established:
  - "Auto-discovery helpers use recursive depth-limited search"
  - "Platform stubs always return NULL, never non-NULL"

# Metrics
duration: 98s
completed: 2026-02-05
---

# Phase 33 Plan 01: MTKView Discovery API Summary

**MTKView auto-discovery from NSWindow via recursive view hierarchy walk with hard error on failure**

## Performance

- **Duration:** 1 min 38 sec
- **Started:** 2026-02-05T18:11:54Z
- **Completed:** 2026-02-05T18:13:32Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- MTKView discovery helper walks NSWindow view hierarchy recursively
- Auto-create API combines discovery + existing overlay creation
- V bindings expose discovery and auto-create to vglyph module
- Hard error pattern (NULL return) when MTKView not found

## Task Commits

Each task was committed atomically:

1. **Task 1: Add MTKView discovery and auto-create API** - `0d177a3` (feat)
2. **Task 2: Add V bindings for auto-discover API** - `d1e168e` (feat)

## Files Created/Modified

- `ime_overlay_darwin.h` - Added vglyph_discover_mtkview_from_window and
vglyph_create_ime_overlay_auto declarations
- `ime_overlay_darwin.m` - Implemented findViewByClass recursive helper with depth limit 100,
discovery function, auto-create wrapper
- `ime_overlay_stub.c` - Added Linux stubs for new functions returning NULL
- `c_bindings.v` - Added ime_discover_mtkview and ime_overlay_create_auto V wrappers

## Decisions Made

- **Depth limit 100** for view hierarchy traversal (sanity check, real hierarchy is 2-3 levels)
- **Hard error on MTKView not found** - Returns NULL with stderr message, no silent fallback
per CONTEXT.md
- **void* parameters only** in public header - MTKView*, NSWindow* types remain internal to .m

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Auto-discovery API ready for editor_demo integration
- Unblocks IME-01 (switch to per-overlay callbacks)
- Unblocks IME-02 (refactor callback patterns)
- Unblocks IME-06 (multi-field IME routing)
- No blockers

---
*Phase: 33-overlay-api-wiring*
*Completed: 2026-02-05*
