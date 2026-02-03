---
phase: "13"
plan: "01"
subsystem: "text-mutation"
tags: ["mutation", "editing", "grapheme", "strings.Builder"]
dependency-graph:
  requires: ["11-cursor", "12-selection"]
  provides: ["MutationResult", "delete_backward", "delete_forward", "insert_text", "delete_selection"]
  affects: ["14-undo-redo", "17-api-demo"]
tech-stack:
  added: []
  patterns: ["pure function mutation", "strings.Builder for efficient concat"]
key-files:
  created: ["layout_mutation.v"]
  modified: []
decisions:
  - id: "mutation-pure-functions"
    choice: "Return MutationResult, app applies"
    rationale: "VGlyph is renderer, not editor - app owns text"
metrics:
  duration: "~2 minutes"
  completed: "2026-02-03"
---

# Phase 13 Plan 01: Core Mutation Primitives Summary

Text mutation primitives using grapheme-aware deletion via layout.move_cursor_* and strings.Builder
for efficient string construction.

## What Was Built

### MutationResult Struct
Central return type for all mutation operations:
- `new_text`: Result string after mutation
- `cursor_pos`: New cursor position
- `deleted_text`: Text removed (for undo support)
- `range_start`/`range_end`: Affected range (for change events)

### Core Deletion Functions
- `delete_backward`: Backspace - uses move_cursor_left for grapheme boundary
- `delete_forward`: Delete key - uses move_cursor_right for grapheme boundary
- `delete_to_word_boundary`: Option+Backspace - uses move_cursor_word_left
- `delete_to_line_start`: Cmd+Backspace - uses move_cursor_line_start
- `delete_to_line_end`: Cmd+Delete - uses move_cursor_line_end
- `delete_to_word_end`: Option+Delete - uses move_cursor_word_right

### Insertion Functions
- `insert_text`: Simple cursor insertion
- `insert_replacing_selection`: Replaces selection if present, delegates to insert_text otherwise

### Selection-Aware Deletion
- `delete_selection`: Handles cursor > anchor and cursor < anchor cases

## Key Implementation Details

All functions are pure - they return MutationResult without side effects. The app:
1. Calls mutation function
2. Applies result.new_text
3. Updates cursor to result.cursor_pos
4. Regenerates layout via layout_text

strings.Builder used in all 9 string construction sites for O(n) instead of O(n^2).

## Verification Results

```
v fmt -w layout_mutation.v  # Already formatted
v -check-syntax layout_mutation.v  # No errors
```

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Pure functions | Return MutationResult | VGlyph renders, app owns text |
| strings.Builder | Always use | O(n) vs O(n^2) concat |
| Selection bounds | min/max of cursor/anchor | Handle both directions |

## Deviations from Plan

None - plan executed exactly as written.

## What's Next

Phase 13-02 will integrate these primitives into the editor demo with keyboard event handling.

## Files

| File | Status | Lines | Purpose |
|------|--------|-------|---------|
| layout_mutation.v | Created | 253 | Text mutation primitives |
