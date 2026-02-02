# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-02)

**Core value:** Reliable text rendering without crashes or undefined behavior
**Current focus:** v1.3 Text Editing

## Current Position

Phase: Phase 11 - Cursor Foundation
Plan: 2 of 2 complete
Status: Phase complete
Last activity: 2026-02-02 - Completed 11-02-PLAN.md (Cursor Navigation)

Progress: [██░░░░░░░░] 1/7 phases complete (Phase 12 next)

## Performance Metrics

Latest profiled build metrics (from v1.2 Phase 10 completion):
- Glyph cache: 4096 entries (LRU eviction)
- Metrics cache: 256 entries (LRU eviction)
- Atlas: Multi-page (4 max), LRU page eviction
- Layout cache: TTL-based eviction
- Frame timing: instrumented via `-d profile`

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full history.

v1.3 decisions:
- v-gui owns blink timer, VGlyph provides cursor geometry
- macOS primary for IME, other platforms later
- Targeting all three use cases: code editor, rich text, simple inputs
- Phase order: Cursor -> Selection -> Mutation -> Undo/Redo -> IME -> API & Demo -> Accessibility
- 7 phases (11-17) for v1.3 milestone
- v-gui widget changes tracked in separate v-gui milestone

Phase 11-01 decisions:
- Use Pango C struct members directly (not packed u32) for LogAttr access
- Cursor position uses cached char_rects with line fallback for edge cases
- ~~LogAttr array has len = text.len + 1 (position before each char + end)~~ (superseded)

Phase 11-02 decisions:
- Add log_attr_by_index map for byte-to-logattr lookup (fixes multi-byte/emoji)
- Cursor movement uses sorted valid position arrays, not byte iteration
- get_closest_offset returns only valid cursor positions (existing in char_rect_by_index)

### Pending Todos

None.

### Blockers/Concerns

None. Cursor foundation complete with full navigation support.

## Session Continuity

Last session: 2026-02-02
Stopped at: Completed 11-02-PLAN.md (Cursor Navigation)
Resume file: .planning/phases/12-selection/12-PLAN.md (when created)
