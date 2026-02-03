---
phase: 12-selection
plan: 01
subsystem: layout
tags: [selection, mouse, drag, word-snap, auto-scroll]

# Dependency graph
requires:
  - phase: 11-02
    provides: Cursor movement APIs, log_attr_by_index mapping
provides:
  - Selection state management (anchor-focus model)
  - Click-drag selection with highlight rendering
  - Option+drag word-snap selection
  - Auto-scroll during drag near edges
  - get_word_at_index API for word boundary lookup
affects: [12-02-keyboard-selection, 13-text-mutation, v-gui-editor]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Anchor-focus selection state (anchor fixed, cursor moves)
    - Distance-based auto-scroll acceleration
    - Modifier-aware drag behavior (Option for word snap)

key-files:
  created: []
  modified:
    - layout_query.v
    - examples/editor_demo.v

key-decisions:
  - "Anchor-focus model: anchor stays at initial click, cursor moves with drag"
  - "Option+drag snaps to word boundaries using get_word_at_index"
  - "Auto-scroll accelerates with distance past edge threshold"

patterns-established:
  - "Selection range: min(anchor, cursor) to max(anchor, cursor)"
  - "has_selection flag for efficient selection state checks"
  - "scroll_offset applied to both rendering and hit-testing"

# Metrics
duration: 3min
completed: 2026-02-02
---

# Phase 12 Plan 01: Selection State and Click-Drag Summary

**Anchor-focus selection model with click-drag, Option+drag word snap, and auto-scroll during drag**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-03T00:43:08Z
- **Completed:** 2026-02-03T00:46:11Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Selection state using anchor-focus model (anchor fixed, cursor moves)
- get_word_at_index API for word boundary lookup
- Click-drag selection with blue highlight rendering
- Option+drag snaps selection to word boundaries
- Auto-scroll when dragging near text area edges
- Scroll acceleration based on distance from edge

## Task Commits

Each task was committed atomically:

1. **Task 1: Add selection state and word boundary helper** - `7c2f6af` (feat)
2. **Task 2: Implement click-drag selection with Option+drag** - `f41eea5` (feat)
3. **Task 3: Implement auto-scroll during drag** - `2fbee8c` (feat)

## Files Created/Modified

- `layout_query.v` - Added get_word_at_index, get_word_ends helpers
- `examples/editor_demo.v` - Selection state, mouse handling, auto-scroll

## Decisions Made

1. **Anchor-focus model:** Selection tracks fixed anchor (initial click) and moving cursor.
   Allows selection direction tracking and proper Shift-click extension (Plan 02).

2. **Option+drag word snap:** Uses get_word_at_index to find word boundaries, snaps
   cursor to word end when dragging right, word start when dragging left.

3. **Auto-scroll constants:** 30px edge threshold, 3px base speed, 0.15 acceleration
   per pixel past threshold. Provides responsive but controllable scrolling.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Selection state foundation complete
- Ready for Plan 02: Keyboard selection (Shift+Arrow) and multi-click word/paragraph
- Multi-click tracking fields already added (last_click_time, click_count)

---
*Phase: 12-selection*
*Completed: 2026-02-02*
