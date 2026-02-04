# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-04)

**Core value:** Reliable text rendering without crashes or undefined behavior
**Current focus:** v1.5 Codebase Quality Audit

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-02-04 — Milestone v1.5 started

Progress: ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 0/0 plans

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full history.

Recent decisions:
- Overlay sibling positioning (avoid Metal conflicts)
- Per-overlay callbacks (multi-field support)
- Block undo/redo during composition
- Korean first-keypress workarounds (best-effort, macOS bug)

### Pending Todos

None.

### Known Issues

**Korean IME first-keypress** — macOS-level bug, reported upstream. User workaround: type first
character twice, or refocus field.

**Overlay API limitation** — editor_demo uses global callback API because gg doesn't expose MTKView
handle. Multi-field apps need native handle access.

## Session Continuity

Last session: 2026-02-04
Stopped at: v1.5 milestone started
Resume file: None
Resume command: `/gsd:plan-phase 22`
