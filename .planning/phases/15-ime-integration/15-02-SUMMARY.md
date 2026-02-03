---
phase: 15-ime-integration
plan: 02
subsystem: text-input
tags: [ime, macos, nstextinputclient, objc, composition]

# Dependency graph
requires:
  - phase: 15-01
    provides: CompositionState types for preedit tracking
provides:
  - Native macOS IME bridge via NSTextInputClient protocol
  - C callback interface for V integration
  - Candidate window positioning via composition bounds
affects: [15-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSView category to add NSTextInputClient to sokol view"
    - "C callbacks bridge Obj-C events to V composition state"
    - "IMEBoundsCallback returns screen coords for candidate window"

key-files:
  created:
    - ime_bridge_macos.m
  modified:
    - c_bindings.v

key-decisions:
  - "Category on NSView (not subclass) to add IME to sokol"
  - "Global callbacks + user_data pointer for V integration"
  - "Coordinate conversion (top-left to bottom-left) in firstRectForCharacterRange"

patterns-established:
  - "Native bridge pattern: Obj-C forwards to C callbacks, V registers via c_bindings"

# Metrics
duration: 1m 48s
completed: 2026-02-03
---

# Phase 15 Plan 02: IME Bridge Summary

**NSTextInputClient bridge forwards macOS IME events to V via C callbacks for preedit and
candidate positioning**

## Performance

- **Duration:** 1m 48s
- **Started:** 2026-02-03T17:21:00Z
- **Completed:** 2026-02-03T17:22:48Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- NSTextInputClient protocol implementation on sokol's NSView via category
- C callback types for preedit updates, text commits, and composition cancel
- Candidate window positioning via firstRectForCharacterRange with coordinate conversion
- Build integration documentation for compiling Objective-C into V projects

## Task Commits

Each task was committed atomically:

1. **Task 1: Create IME callback types and V-side interface** - `cc0d7b5` (feat)
2. **Task 2: Create native macOS IME bridge** - `365ae6a` (feat)
3. **Task 3: Add build integration for native bridge** - `d30d0cc` (docs)

## Files Created/Modified
- `c_bindings.v` - Added IME callback types (IMEMarkedTextCallback, IMEInsertTextCallback,
  IMEUnmarkTextCallback, IMEBoundsCallback) and vglyph_ime_register_callbacks declaration
- `ime_bridge_macos.m` - NSTextInputClient protocol implementation as category on NSView, forwards
  setMarkedText/insertText/unmarkText to V callbacks, converts coordinates for candidate window

## Decisions Made

**Category on NSView (not subclass):** Sokol creates its view dynamically, so we extend existing
NSView via Objective-C category rather than subclassing. This allows IME support without modifying
sokol internals.

**Global callbacks + user_data pointer:** Bridge stores callbacks in static globals, receives
opaque user_data pointer from V. V code registers callbacks via vglyph_ime_register_callbacks,
passes pointer to composition state or app context.

**Coordinate conversion in firstRectForCharacterRange:** macOS screen coordinates use bottom-left
origin. Bridge queries V for composition bounds (top-left), converts to screen coords accounting
for window position and screen height.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

Native bridge complete, ready for:
- Plan 15-03: Integrate bridge with composition state in V editor context
- Wire up callbacks to call CompositionState.set_marked_text/commit/cancel
- Implement IMEBoundsCallback to query layout for composition bounds
- Handle preedit rendering with underlines per clause style

No blockers. Next plan implements V-side integration and rendering.

---
*Phase: 15-ime-integration*
*Completed: 2026-02-03*
