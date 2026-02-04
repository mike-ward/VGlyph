# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-03)

**Core value:** Reliable text rendering without crashes or undefined behavior
**Current focus:** v1.4 CJK IME — Phase 19 NSTextInputClient Protocol COMPLETE

## Current Position

Phase: 19 of 21 (NSTextInputClient Protocol)
Plan: 3 of 3 complete
Status: Phase complete
Last activity: 2026-02-04 — Completed 19-03-PLAN.md

Progress: ██████████████████████████████ 32/32+ plans

## Performance Metrics

Latest profiled build metrics (from v1.2 Phase 10):
- Glyph cache: 4096 entries (LRU eviction)
- Metrics cache: 256 entries (LRU eviction)
- Atlas: Multi-page (4 max), LRU page eviction
- Layout cache: TTL-based eviction
- Frame timing: instrumented via `-d profile`

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full history.

v1.3 key decisions archived:
- Byte-to-logattr mapping for UTF-8/emoji cursor
- Anchor-focus selection model
- Pure function mutation (MutationResult)
- 1s coalescing timeout for undo
- 150ms announcement debounce

v1.4 approach decision:
- Overlay NSView architecture (transparent sibling above MTKView)
- No sokol modifications (project constraint)

v1.4 Phase 18 decisions:
- Overlay sibling positioning: Sibling above MTKView (not child) to avoid Metal rendering
- ARC memory management: __bridge_retained for C ownership transfer

v1.4 Phase 19 decisions:
- Per-overlay callbacks (not global) to support multiple text fields
- cursor_pos in callback is selectedRange.location (byte offset within preedit)
- Thick underline = selected clause (style=2), other underlines = raw (style=0)
- Y-flip: self.bounds.size.height - y - h for macOS bottom-left origin
- Handler methods on CompositionState to encapsulate callback processing
- TextSystem.draw_composition wraps Renderer (private) for public API

### Pending Todos

None.

### Blockers/Concerns

**CJK IME approach** (documented 2026-02-03):
- Overlay approach has CEF precedent but not tested with sokol specifically
- Korean jamo backspace behavior less documented than Japanese/Chinese
- Research confidence: MEDIUM-HIGH overall

**Overlay API limitation** (documented 2026-02-04):
- editor_demo uses global callback API because gg doesn't expose MTKView handle
- Overlay API is implemented but registration commented out pending native handle access
- Single-field apps work fine; multi-field apps need native handle access

### Known Issues

None active.

## Session Continuity

Last session: 2026-02-04
Stopped at: Completed Phase 19 (all 3 plans)
Resume file: None
Next: Phase 20 (CJK IME Testing) or Phase 21 (Korean Hangul Backspace)
