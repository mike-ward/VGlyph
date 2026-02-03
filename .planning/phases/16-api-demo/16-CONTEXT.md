# Phase 16: API & Demo - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Clean editing API surface and working demo application that exercises all VGlyph editing primitives
(cursor, selection, mutation, undo, IME). v-gui widget modifications are tracked in a separate
v-gui milestone.

</domain>

<decisions>
## Implementation Decisions

### API Documentation Style
- Both inline docstrings AND separate markdown guide
- Minimal snippets in guide (show API calls, assume context)
- Separate IME appendix: main guide covers working features, appendix documents future CJK IME plan

### Demo Application Scope
- Single unified demo exercising cursor, selection, mutation, undo, IME together
- Lorem ipsum with emoji clusters to test grapheme handling visually
- Status bar showing cursor position (line:col, selection range, undo stack depth)

### API Surface Design
- Keep methods-on-Layout pattern (already established in Phases 11-15)
- Keep MutationResult pattern (pure functions, app applies changes)
- No new convenience helpers — document primitives, let v-gui build its abstractions
- Review and standardize error handling across editing APIs (consistent ?T vs Option returns)

### Claude's Discretion
- Whether to include v-gui integration notes section in guide
- Specific lorem ipsum content (with emoji)
- Status bar formatting details

</decisions>

<specifics>
## Specific Ideas

- Phases 11-15 established the patterns — don't change working code
- v-gui integration is separate work in v-gui's milestone
- Demo already exists (editor_demo.v) — enhance rather than rewrite

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 16-api-demo*
*Context gathered: 2026-02-03*
