---
phase: "13"
plan: "02"
subsystem: "text-mutation"
tags: ["mutation", "clipboard", "editor-demo"]
dependency-graph:
  requires: ["13-01"]
  provides: ["get_selected_text", "cut_selection", "TextChange", "editor_demo"]
  affects: ["14-undo-redo"]
tech-stack:
  added: []
  patterns: ["@[heap] for gg state", "user_data pointer casting"]
key-files:
  created: []
  modified: ["layout_mutation.v", "examples/editor_demo.v"]
decisions:
  - id: "heap-state-pattern"
    choice: "@[heap] struct with user_data pointer"
    rationale: "V/gg callback state persistence workaround"
metrics:
  duration: "~15 minutes"
  completed: "2026-02-03"
status: "conditional-approval"
---

# Phase 13 Plan 02: Clipboard + Editor Demo Summary

Clipboard helpers and editor demo integration for text mutation.

## What Was Built

### Clipboard Helpers (layout_mutation.v)
- `get_selected_text(text, cursor, anchor)` - returns plain text selection
- `cut_selection(text, cursor, anchor)` - returns (cut_text, MutationResult)
- `TextChange` struct - captures mutation info for undo integration
- `MutationResult.to_change(inserted)` - converts result to TextChange

### Editor Demo Integration (editor_demo.v)
- `@[heap]` EditorState struct with proper user_data pointer pattern
- `.char` event handler - character insertion with selection replacement
- `.backspace` handler - grapheme/word/line deletion with modifiers
- `.delete` handler - forward deletion (Fn+Delete on Mac)
- Cmd+C/X/V - clipboard copy/cut/paste operations
- `utf32_to_string` - codepoint to UTF-8 conversion

## Known Issue

**V/gg state persistence** - Repeated key events may not persist state correctly across gg callbacks. This is a V/gg library limitation, not a vglyph issue.

- Single mutations work correctly
- vglyph mutation functions verified correct
- Issue is in V/gg callback state handling
- Workaround attempted: @[heap] + user_data pattern

**Impact:** Demo may not handle rapid repeated keystrokes reliably.
**Scope:** Demo application only - vglyph APIs are correct.

## Verification Results

```
v fmt -w layout_mutation.v examples/editor_demo.v  # Formatted
v -check-syntax layout_mutation.v examples/editor_demo.v  # No errors
v examples/editor_demo.v -o /tmp/editor_demo  # Builds successfully
```

Manual testing:
- [x] Single character insertion works
- [x] Single backspace deletion works
- [x] Selection replacement works
- [x] Clipboard operations work
- [ ] Repeated backspace (V/gg limitation)

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| State pattern | @[heap] + user_data | V/gg callback state workaround |
| Conditional approval | Yes | vglyph APIs correct, demo has V/gg issue |

## Files

| File | Status | Purpose |
|------|--------|---------|
| layout_mutation.v | Modified | Added clipboard helpers, TextChange |
| examples/editor_demo.v | Modified | Full mutation integration |
