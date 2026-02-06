# Phase 38: macOS Accessibility Completion

**Goal:** Complete the `DarwinAccessibilityBackend` implementation to enable VoiceOver support on macOS.

## Context
The current accessibility backend for macOS is a skeleton. It has definitions but the core logic for building the accessibility tree, setting properties, and handling interactions is commented out or missing.

## Plans
- **38-01: Core Tree Implementation**
  - Wire up `get_window` using `sapp`.
  - Implement `update_tree` to create elements, set labels/frames, and build hierarchy.
  - Attach root to NSWindow.
- **38-02: Interaction & Text Support**
  - Implement `update_text_field` (Value, Selection).
  - Implement `set_focus` and `post_notification`.
  - Add NSValue helpers for Range wrapping.
- **38-03: Verification**
  - Create `examples/accessibility_check.v`.
  - Verify cross-platform stubs.

## Success Criteria
- [ ] `get_window` returns valid window.
- [ ] Accessibility Tree is visible in Xcode Accessibility Inspector.
- [ ] Elements have correct Frames (screen coords) and Labels.
- [ ] Text Fields update value and selection.
- [ ] Focus moves correctly.
