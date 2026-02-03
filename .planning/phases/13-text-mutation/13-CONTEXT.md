# Phase 13: Text Mutation - Context

**Gathered:** 2026-02-02
**Status:** Ready for planning

<domain>
## Phase Boundary

User can insert, delete, and modify text content. Core editing primitives that transform text at cursor
or replace selection. Clipboard integration via v-gui (VGlyph provides text, v-gui handles pasteboard).

</domain>

<decisions>
## Implementation Decisions

### Character Insertion
- Typing with selection active replaces selection (standard behavior)
- Insert mode only — no overwrite mode toggle
- Auto-pairing not in VGlyph — v-gui handles if wanted
- Full grapheme cluster support — insert at grapheme boundaries, cursor moves by cluster

### Deletion Behavior
- Backspace deletes one grapheme cluster (emoji = 1 backspace)
- Option+Backspace deletes to word boundary (not whole word)
- Cmd+Backspace deletes to line start
- Delete key mirrors Backspace (forward direction)
- Selection active: Backspace/Delete remove selection only, cursor at start

### Clipboard Operations
- v-gui handles system pasteboard access
- VGlyph copy API returns plain text only (selected text as string)
- Paste uses generic `insert_text(string)` — no separate paste method
- Cut returns selection text + deletes it, v-gui copies to pasteboard

### Change Events
- Callback on mutation — VGlyph calls user-provided callback after each mutation
- Callback receives: range (start/end offset) + new text
- Batch rapid mutations into single change event (holding backspace coalesced)

### Claude's Discretion
- Layout invalidation timing (immediate vs deferred)
- Specific callback signature details
- Internal batching implementation

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 13-text-mutation*
*Context gathered: 2026-02-02*
