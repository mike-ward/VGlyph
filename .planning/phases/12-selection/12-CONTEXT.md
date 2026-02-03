# Phase 12: Selection - Context

**Gathered:** 2026-02-02
**Status:** Ready for planning

<domain>
## Phase Boundary

User can select text ranges for copy/cut operations. Includes click-drag selection, keyboard selection extension, double/triple-click word/paragraph selection, and select-all. Provides selection rects API for highlight geometry. Clipboard operations (copy/cut/paste) belong to Phase 13.

</domain>

<decisions>
## Implementation Decisions

### Selection appearance
- Claude decides highlight color (follow standard editor conventions)
- Dimmed highlight when window loses focus
- Sharp rectangles for selection rects (no rounded corners)
- Selection extends to wrap width on multi-line (VS Code style)

### Drag behavior
- Auto-scroll when cursor near text area edge
- Accelerating scroll speed as cursor moves further past edge
- Option+drag snaps to word-by-word selection
- Fixed anchor position — initial click is anchor, selection extends from there
- Click elsewhere (no shift) clears selection and repositions cursor
- Shift+click extends from anchor, not cursor
- Selection follows logical lines, not visual wraps
- Click inside existing selection starts new selection (no drag-to-move)

### Keyboard selection
- Shift+Arrow selects by grapheme clusters (matches cursor movement)
- Cmd+Shift+Arrow word selection includes trailing space (macOS convention)
- Shift+Home/End selects to logical line edge (past wraps)
- Arrow without Shift collapses selection to direction (left→start, right→end)

### Multi-click behavior
- Word definition: Pango word boundaries (is_word_start/end)
- Triple-click selects entire paragraph (until empty line)
- Double-click timing: fixed 400ms threshold
- Double-click on whitespace snaps to adjacent word

### Claude's Discretion
- Exact highlight color choice
- Loading/rendering optimization
- Selection rect caching strategy
- Edge case handling for empty text

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-selection*
*Context gathered: 2026-02-02*
