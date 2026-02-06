# Phase 40: IME API Refinement and Encapsulation

## Goal
Move repetitive IME callback logic from the application layer into `api.v` to improve consistency, security (centralized validation), and reduce boilerplate.

## Requirements
1.  **Refactor `TextSystem`**: Optionally manage `CompositionState` and `DeadKeyState`.
2.  **StandardIMEHandler**: Provide a standard handler in `api.v` implementing common callback patterns.
3.  **Validation**: Centralize `validate_text_input` within the standard handler.
4.  **Boilerplate Reduction**: Update `editor_demo.v` to use the new handler, significantly reducing its LOC.
5.  **Extensibility**: Maintain support for custom handlers.
6.  **Decoupling**: Use callbacks for committing text to decouple `TextSystem` from app-specific data structures.

## Decisions
- `TextSystem` will gain `composition` and `dead_key` fields.
- `StandardIMEHandler` will be a struct in `api.v` containing callbacks for app-specific logic (`on_commit`, `on_update`, `get_layout_info`).
- The user-provided `StandardIMEHandler` will be passed as `user_data` to the native IME callbacks.
- Library will provide static wrapper functions that invoke `StandardIMEHandler` methods.

## Deferred Ideas
- None.

## Claude's Discretion
- Placing `StandardIMEHandler` and its associated static callbacks in `api.v` as requested, though some logic resides in `composition.v`.
- Structuring `StandardIMEHandler` to handle both "global" and "overlay" IME paths.
