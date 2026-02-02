---
phase: 03-layout-safety
plan: 01
subsystem: layout
tags: [pointer-cast, string-lifetime, pango, ffi-safety]

dependency-graph:
  requires: []
  provides: [documented-pointer-cast, string-lifetime-management, layout-destroy]
  affects: []

tech-stack:
  added: []
  patterns: [debug-validation, clone-before-ffi]

key-files:
  created: []
  modified: [layout.v, layout_types.v]

decisions:
  - id: "03-01-01"
    choice: "panic for debug null check"
    reason: "Consistent with user decision from planning phase"
  - id: "03-01-02"
    choice: "skip cloning empty strings"
    reason: "Per user decision - no point cloning empty IDs"

metrics:
  duration: "1 min"
  completed: "2026-02-01"
---

# Phase 03 Plan 01: Layout Safety Summary

**One-liner:** Document PangoLayoutRun cast with debug validation, clone inline object IDs for Pango
lifetime

## What Changed

### Task 1: Pointer Cast Documentation
- Added inline comment explaining PangoLayoutRun is typedef for PangoGlyphItem
- Added Pango API reference URL
- Added `$if debug` block with panic on null cast result

### Task 2a: Layout Struct Updates
- Added `cloned_object_ids []string` field to Layout struct
- Added `Layout.destroy()` method that frees cloned strings

### Task 2b: String Cloning Wiring
- Updated `apply_rich_text_style` signature to accept `mut cloned_ids []string`
- Clones `obj.id` before passing to Pango shape attribute (skips empty strings)
- `layout_rich_text` creates array, passes through, assigns to Layout result

## Commits

| Hash | Message |
|------|---------|
| 9489cc1 | docs(03-01): document pointer cast with debug validation |
| e817779 | feat(03-01): add cloned_object_ids field and destroy method |
| b77a512 | fix(03-01): wire string cloning for inline object IDs |

## Files Modified

- `layout.v`: Pointer cast docs, debug check, apply_rich_text_style signature, cloning logic
- `layout_types.v`: cloned_object_ids field, destroy() method

## Verification

All verification criteria met:
- [x] Comment exists above pointer cast at line ~157-158
- [x] `$if debug` block exists after cast
- [x] Layout struct has cloned_object_ids field
- [x] Layout.destroy() method exists and frees strings
- [x] apply_rich_text_style has cloned_ids parameter
- [x] layout_rich_text creates cloned_ids array
- [x] layout_rich_text assigns cloned_ids to result
- [x] Code compiles with `v -check-syntax`

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

Phase 03 Plan 01 complete. Layout safety issues addressed:
- Pointer cast documented with API reference
- Debug builds validate cast result
- Inline object ID strings properly cloned and freed
