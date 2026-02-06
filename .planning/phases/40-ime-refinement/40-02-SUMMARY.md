---
phase: 40-ime-refinement
plan: 02
subsystem: api
tags: [ime, api, encapsulation]
requires: [40-01]
provides: [StandardIMEHandler]
affects: [editor-demo, applications]
tech-stack:
  added: []
  patterns: [standard-handler-pattern, static-c-wrappers]
key-files:
  created: []
  modified: [api.v]
decisions:
  - Provide StandardIMEHandler to encapsulate TextSystem-linked IME state.
  - Implement static wrappers (ime_standard_*) to bridge C callbacks to StandardIMEHandler.
  - Add get_cursor_index callback to StandardIMEHandler to correctly start composition.
  - Use unsafe casting in callbacks to retrieve StandardIMEHandler from voidptr.
metrics:
  duration: 20m
  completed: 2026-02-06
---

# Phase 40 Plan 02: Provide StandardIMEHandler and callbacks in api.v Summary

Implemented `StandardIMEHandler` and associated C-compatible static wrappers in `api.v`. This provides a high-level, standardized way for applications to integrate IME support using `TextSystem` with minimal boilerplate.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Define StandardIMEHandler and Callbacks | 345ed83 | api.v |

## Deviations from Plan

- **Added `get_cursor_index` to `StandardIMEHandler`**: Necessary for `handle_marked_text` to correctly set `preedit_start` when beginning a new composition.
- **Fixed mutability and safety in callbacks**: Wrapped `voidptr` casting in `unsafe` blocks and ensured `handler` is `mut` to allow updating `CompositionState`.
- **Initialized `fn` fields**: Initialized all function pointer fields in `StandardIMEHandler` to `unsafe { nil }` to satisfy V's safety requirements for struct fields.

## Self-Check: PASSED

- [x] StandardIMEHandler struct exists in api.v.
- [x] Static wrapper functions (ime_standard_*) exist in api.v.
- [x] StandardIMEHandler implements commit, marked, and bounds logic.
- [x] Validation is applied within the handler (via CompositionState methods).
- [x] api.v compiles successfully (`v -shared .`).
