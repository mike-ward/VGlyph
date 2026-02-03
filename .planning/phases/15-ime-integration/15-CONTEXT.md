# Phase 15: IME Integration - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable CJK and accented character input via system Input Method Editor. VGlyph provides composition
state management, preedit display, and cursor geometry for IME candidate window positioning. macOS
is the primary target platform.

</domain>

<decisions>
## Implementation Decisions

### Composition Display
- Single underline under preedit text (standard IME convention)
- Cursor visible inside composition text for navigation
- Multi-clause segments: thick underline for selected clause, thin for others
- Preedit text uses same color as regular text (underline distinguishes)

### Candidate Window Positioning
- Candidate window appears below cursor line (standard position)
- Let macOS handle screen-edge collision — don't adjust in VGlyph
- Coordinate space: Claude's discretion based on macOS IME requirements
- API reports full composition bounds (rect covering entire preedit), not just cursor point

### Composition Behavior
- Focus loss: commit preedit as-is (auto-commit)
- Escape: cancel composition entirely (discard preedit, revert)
- Click outside preedit: commit then move cursor to click location
- Arrow keys during composition: navigate within preedit (don't break out)

### Dead Key Sequences
- Show dead key character as placeholder until combined (e.g., ` visible)
- Invalid combination (e.g., ` + x): insert both separately as `x
- Dead key styled same as preedit (single underline)
- Escape cancels pending dead key state

### Claude's Discretion
- Exact coordinate transformation for IME API
- Underline thickness/styling details
- Internal state machine design

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following macOS IME conventions.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 15-ime-integration*
*Context gathered: 2026-02-03*
