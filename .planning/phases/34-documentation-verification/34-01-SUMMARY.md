---
phase: 34-documentation-verification
plan: 01
subsystem: documentation
tags: [markdown, ime, overlay-api, security, api-docs]

# Dependency graph
requires:
  - phase: 33-overlay-api-wiring
    provides: Overlay API implementation with MTKView discovery
provides:
  - Complete documentation of overlay API in all docs
  - Security analysis of NSView hierarchy discovery
  - Updated IME integration examples
affects: [onboarding, future-ime-platforms]

# Tech tracking
tech-stack:
  added: []
  patterns: [overlay-api-pattern, ime-callback-registration]

key-files:
  created: []
  modified:
    - docs/SECURITY.md
    - README.md
    - docs/IME-APPENDIX.md
    - docs/EDITING.md
    - docs/API.md

key-decisions:
  - "Overlay API as primary IME path in README"
  - "Trust boundary diagram for NSView discovery"
  - "CJK IME moved from Future to shipped"

patterns-established:
  - "Overlay lifecycle: create -> register -> set_field -> free"
  - "Auto-discovery pattern with NULL fallback"

# Metrics
duration: 5min
completed: 2026-02-05
---

# Phase 34 Plan 01: Update all docs for overlay API Summary

**All docs updated: overlay API primary IME path, NSView discovery trust
boundary, CJK IME shipped not future**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-05T19:19:42Z
- **Completed:** 2026-02-05T19:24:42Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- SECURITY.md documents NSView hierarchy discovery with trust boundary diagram
- README.md shows overlay API as primary IME integration with code example
- IME-APPENDIX.md reflects overlay as shipped (not future work)
- EDITING.md documents overlay callback registration pattern
- API.md lists all ime_overlay_* public functions with parameters

## Task Commits

Each task was committed atomically:

1. **Task 1: Update SECURITY.md and README.md** - `bface86` (docs)
2. **Task 2: Update IME-APPENDIX, EDITING, API docs** - `7c29808` (docs)

## Files Created/Modified

- `docs/SECURITY.md` - Added NSView hierarchy discovery section with trust
  boundary diagram and safety analysis
- `README.md` - Added IME support section with overlay API code example
- `docs/IME-APPENDIX.md` - Updated CJK IME section from "Future Work" to
  "Overlay API (v1.8+)"
- `docs/EDITING.md` - Added overlay callback registration pattern and lifecycle
- `docs/API.md` - Added IME Overlay API section with all public functions

## Decisions Made

- **Overlay API as primary path** - README now shows overlay API first (macOS),
  global callbacks second (cross-platform fallback)
- **Trust boundary documentation** - SECURITY.md explicitly documents NSView
  discovery as trusted->boundary->validated flow
- **CJK IME status change** - Moved from "Future Work" to shipped feature
  (v1.8+) with known Korean issue documented

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 34 plan 2/2 ready for execution (final verification).

All overlay API documentation complete and consistent across files.

---
*Phase: 34-documentation-verification*
*Completed: 2026-02-05*
