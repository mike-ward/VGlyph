---
phase: 11-cursor-foundation
plan: 02
subsystem: layout
tags: [pango, cursor, navigation, emoji, grapheme, keyboard]

# Dependency graph
requires:
  - phase: 11-01
    provides: LogAttr struct and log_attrs array in Layout
provides:
  - 8 cursor movement methods (left/right/word/line/up/down)
  - Proper multi-byte character handling via byte-to-logattr mapping
  - Editor demo with full keyboard navigation
affects: [12-selection, v-gui-editor, text-editing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Byte-to-logattr index mapping for UTF-8/emoji handling
    - Valid cursor positions from log_attr_by_index keys
    - Cursor movement via sorted position array scanning

key-files:
  created: []
  modified:
    - layout_types.v
    - layout.v
    - layout_query.v
    - examples/editor_demo.v

key-decisions:
  - "Add log_attr_by_index map for byte-to-logattr lookup (fixes emoji navigation)"
  - "Cursor movement methods use sorted valid position arrays, not byte iteration"
  - "get_closest_offset returns only valid cursor positions"

patterns-established:
  - "Multi-byte char handling: use log_attr_by_index map, not raw byte iteration"
  - "Cursor movement: get_valid_cursor_positions() returns sorted byte indices"
  - "Click handling: only return indices that exist in char_rect_by_index"

# Metrics
duration: 45min
completed: 2026-02-02
---

# Phase 11 Plan 02: Cursor Navigation Summary

**8 cursor movement methods with proper emoji/grapheme handling via byte-to-logattr mapping,
plus keyboard navigation demo**

## Performance

- **Duration:** 45 min (including bug fixes from checkpoint feedback)
- **Started:** 2026-02-02T17:00:00Z
- **Completed:** 2026-02-02T17:45:00Z
- **Tasks:** 4 (3 auto + 1 checkpoint with bug fixes)
- **Files modified:** 4

## Accomplishments

- 8 cursor movement methods: left, right, word_left, word_right, line_start, line_end, up, down
- Proper grapheme cluster handling: emoji (flag, family, rainbow) navigate as single units
- Multi-byte UTF-8 character support via byte-to-logattr index mapping
- Editor demo with full keyboard navigation (arrows, Cmd+arrows, Home/End)
- Bug fixes: emoji navigation and last-line click handling

## Task Commits

Each task was committed atomically:

1. **Task 1: Add character-level cursor movement methods** - `ad238b7` (feat)
2. **Task 2: Add line-level cursor movement methods** - `f236cb9` (feat)
3. **Task 3: Add keyboard navigation to editor demo** - `9cbf05d` (feat)
4. **Task 4: Fix emoji navigation and multi-byte handling** - `3b1b999` (fix)

## Files Created/Modified

- `layout_types.v` - Added log_attr_by_index map field to Layout struct
- `layout.v` - Added LogAttrResult struct, updated extract_log_attrs to build byte mapping
- `layout_query.v` - Added 8 cursor movement methods, helper functions for valid positions
- `examples/editor_demo.v` - Keyboard event handling for arrow keys, Home/End

## Decisions Made

1. **Byte-to-logattr mapping:** Pango's log_attrs are indexed by character (grapheme), not
   byte. Added log_attr_by_index map to translate byte indices to logattr array indices.
   This correctly handles multi-byte UTF-8 characters and emoji (which can be 4-18 bytes).

2. **Valid cursor positions via sorted array:** Instead of iterating bytes and checking
   log_attrs, movement methods get sorted list of valid cursor positions and find
   next/previous. More robust for multi-byte characters.

3. **Click returns valid positions only:** get_closest_offset now only returns indices
   that exist in char_rect_by_index, preventing mid-character cursor positions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Emoji cursor navigation jumping to start of line**
- **Found during:** Task 4 (checkpoint verification feedback)
- **Issue:** Arrow keys over emoji caused cursor to jump to index 0. Root cause: log_attrs
  indexed by character position, but code iterated by byte index.
- **Fix:** Added log_attr_by_index mapping, rewrote cursor movement to use valid position
  arrays instead of byte iteration
- **Files modified:** layout_types.v, layout.v, layout_query.v
- **Verification:** Emoji (flag 8 bytes, family 18 bytes) now navigate as single units
- **Committed in:** 3b1b999

**2. [Rule 1 - Bug] Clicking on last line not moving cursor**
- **Found during:** Task 4 (checkpoint verification feedback)
- **Issue:** get_closest_offset returned mid-character byte indices, get_cursor_pos
  couldn't find char_rect, fell back to line start incorrectly
- **Fix:** get_closest_offset now only returns indices with char_rects,
  get_cursor_pos rejects invalid mid-character indices
- **Files modified:** layout_query.v
- **Verification:** Click on any line correctly positions cursor
- **Committed in:** 3b1b999 (combined with emoji fix)

---

**Total deviations:** 2 auto-fixed (2 bugs from checkpoint feedback)
**Impact on plan:** Essential fixes for correct cursor behavior. No scope creep.

## Issues Encountered

The original plan assumed Pango's log_attrs could be indexed directly by byte position.
This works for ASCII but fails for multi-byte UTF-8 characters. The fix required
adding a mapping layer and rewriting cursor movement logic. The research doc had
actually warned about this but the warning wasn't heeded in the initial implementation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Cursor navigation fully functional for all text types (ASCII, UTF-8, emoji)
- Editor demo demonstrates complete keyboard navigation
- Ready for Phase 12: Selection Support
- Note: 11-01 SUMMARY's "log_attrs.len = text.len + 1" decision is now superseded
  by byte-to-logattr mapping approach

---
*Phase: 11-cursor-foundation*
*Completed: 2026-02-02*
