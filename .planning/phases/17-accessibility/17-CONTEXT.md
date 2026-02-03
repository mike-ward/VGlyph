# Phase 17: Accessibility - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

VoiceOver support for text editing. Screen reader users can navigate and edit text with full auditory
feedback. Uses existing editing APIs (cursor, selection, mutation, undo, IME) from Phases 11-15 and
adds accessibility announcements for state changes.

</domain>

<decisions>
## Implementation Decisions

### Announcement verbosity
- Character announcements: character only (not phonetic spelling)
- Punctuation/whitespace: symbolic names ('period', 'comma', 'space', 'tab')
- Word navigation (Option+Arrow): word only, no position context
- Emoji: short name if available (e.g., 'grinning face' not full Unicode name)

### Cursor navigation feedback
- Line boundaries: announce 'beginning of line' / 'end of line' when reached
- Line numbers: always announce when cursor moves to new line ('line 5')
- Word jump / Home/End: brief context preview ('moved to: hello world')
- Document boundaries: announce 'beginning of document' / 'end of document'

### Selection announcements
- Read selected text for short selections, count only for long selections
- Threshold: ~20 characters (read words/phrases, count longer)
- Selection extension (Shift+Arrow): announce new content added ('added: o')
- Selection cleared: announce 'deselected'

### IME composition feedback
- Dead key sequences: announce dead key ('grave accent'), then final result
- Composition cancelled: announce 'composition cancelled'

### Claude's Discretion
- Preedit text announcement format (explicit 'composing:' prefix vs plain text)
- Committed character announcement (whether to confirm insertion)
- Exact timing/debouncing of announcements
- Audio cue usage vs verbal announcements for edge cases

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard macOS VoiceOver conventions for areas marked
Claude's Discretion.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 17-accessibility*
*Context gathered: 2026-02-03*
