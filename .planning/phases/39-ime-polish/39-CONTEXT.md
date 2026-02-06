# Phase 39: IME Quality and Security Polish

**Goal:** Improve consistency, security, and quality of recently added IME code.

## Findings to Address

1.  **RAII Consistency in composition.v**
    - `DeadKeyState` has `clear()`, but `CompositionState` relies on `commit()`/`cancel()`.
    - Requirement: Add explicit `reset()` or `clear()` to both for consistency, ensuring all state is zeroed.

2.  **Null Safety in ime_bridge_macos.m**
    - `vglyph_insertText` suppresses `insertText` during composition but doesn't check if the string is nil.
    - Requirement: Add nil checks to `insertText` and `setMarkedText`.

3.  **Input Validation in ime_overlay_darwin.m**
    - `setMarkedText` casts `selectedRange.location` to `int` without validating against `text.length`.
    - Requirement: Validate ranges before casting/usage.

4.  **Security Validation**
    - Input validation (`validate_text_input`) is missing for IME strings.
    - Requirement: Ensure `validate_text_input` is called for `marked` and `insert` text in `CompositionState` methods.

5.  **Coordinate Conversion**
    - Top-left (VGlyph) to bottom-left (macOS) conversion is duplicated in `.m` files.
    - Requirement: Centralize this logic or document it identically.

6.  **API Safety**
    - Audit `api.v` IME wrappers for null context/renderer checks.

## Decisions
- **Validation Strategy**: `CompositionState` methods (`handle_marked_text`, `handle_insert_text`) should call `validate_text_input`. If invalid, they should return early (ignore input) or return an error (if signature allows). Given these are called from C callbacks (void return), silent failure (logging error) is acceptable/safer than crashing.
- **Coordinate Helper**: Create a static inline helper if possible, or fully document the duplication if a shared header is too heavy for just one function.

## Constraints
- Do not introduce new external dependencies.
- Keep `CompositionState` in `composition.v`.
- Keep native bridge code minimal.
