---
phase: 19-nstextinputclient-jpch
plan: 03
subsystem: ime-callbacks
tags: [ime, composition, rendering, callbacks]

dependency-graph:
  requires: [19-02]
  provides: [ime-callback-handlers, preedit-rendering, draw-composition-api]
  affects: [20, 21]

tech-stack:
  added: []
  patterns:
    - handler-method-pattern: CompositionState methods wrap callback processing
    - api-wrapper-pattern: TextSystem.draw_composition wraps Renderer method

file-tracking:
  created: []
  modified:
    - composition.v
    - renderer.v
    - api.v
    - examples/editor_demo.v

decisions:
  - id: callback-handler-pattern
    choice: Handler methods on CompositionState
    why: Encapsulates callback processing logic within composition state
  - id: textsystem-wrapper
    choice: Add draw_composition to TextSystem wrapping Renderer
    why: Renderer is private; TextSystem is public API
  - id: clause-style-mapping
    choice: Style 2=selected, 1=converted, else=raw
    why: Matches macOS NSTextInputClient attribute conventions

metrics:
  duration: 4m
  completed: 2026-02-04
---

# Phase 19 Plan 03: V-side Callbacks and Preedit Rendering Summary

**One-liner:** IME callback handlers in CompositionState + draw_composition API for preedit
visual feedback with clause underlines.

## What Was Built

### 1. CompositionState Handler Methods (composition.v)

Added 5 handler methods to process IME callbacks:

- `handle_marked_text(text, cursor_in_preedit, document_cursor)`: Starts/updates composition
- `handle_insert_text(text) string`: Clears composition, returns text for insertion
- `handle_unmark_text()`: Cancels composition without inserting
- `handle_clause(start, length, style)`: Accumulates clause info from overlay enumeration
- `clear_clauses()`: Resets clause array before enumeration

Style mapping: 2=selected (thick underline), 1=converted, else=raw (thin underline).

### 2. draw_composition Method (renderer.v)

Added visual feedback rendering for preedit:

- Clause underlines: 2px thick for selected clause, 1px for others
- Underline color at 70% opacity (alpha 178)
- Cursor at insertion point within preedit (70% opacity)
- draw_layout_with_composition placeholder for future opacity support

### 3. TextSystem Wrapper (api.v)

Added `draw_composition` method to TextSystem that wraps Renderer's method, since Renderer is
private to the module.

### 4. editor_demo Wiring (examples/editor_demo.v)

- Added `ime_overlay` field to EditorState for future overlay support
- Added new overlay callback functions using the handler methods
- Updated frame() to use `ts.draw_composition()` instead of manual underline rendering
- Kept compatibility with existing global callback API (overlay API commented pending native
  handle access)

## Key Files

| File | Changes |
|------|---------|
| composition.v | +47 lines: handler methods |
| renderer.v | +56 lines: draw_composition, draw_layout_with_composition |
| api.v | +6 lines: TextSystem.draw_composition wrapper |
| examples/editor_demo.v | +88/-17 lines: callbacks and draw_composition usage |

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 3ea01c1 | feat | Add IME callback handlers to CompositionState |
| f25ba11 | feat | Add draw_composition for preedit rendering |
| 8ec724d | feat | Wire IME callbacks and draw_composition in editor_demo |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed get_cursor_pos call signature**
- **Found during:** Task 2 verification
- **Issue:** Plan showed `layout.get_cursor_pos(cursor_pos, false)` but API takes single argument
- **Fix:** Changed to `layout.get_cursor_pos(cursor_pos)`
- **Files modified:** renderer.v
- **Commit:** 8ec724d

**2. [Rule 2 - Missing Critical] Added TextSystem.draw_composition wrapper**
- **Found during:** Task 3 implementation
- **Issue:** Renderer is private; editor_demo can't call it directly
- **Fix:** Added wrapper method to TextSystem (public API)
- **Files modified:** api.v
- **Commit:** 8ec724d

## Verification Results

- All syntax checks pass
- Editor demo builds successfully
- Callback wiring in place (overlay registration commented pending native handle)
- draw_composition integrated into frame rendering

## Next Phase Readiness

Phase 19 is now complete. All three plans delivered:
- 19-01: CompositionState and DeadKeyState data structures
- 19-02: Native overlay (ime_overlay_darwin.m) with NSTextInputClient
- 19-03: V-side callback handlers and preedit rendering

Ready for Phase 20 (CJK IME Testing) or Phase 21 (Korean Hangul Backspace Handling).

Note: The overlay API is implemented but commented out in editor_demo because gg doesn't expose
the MTKView handle. When that's available, uncommenting the registration will enable per-field
callbacks with clause enumeration. The current global callback API works for single-field apps.
