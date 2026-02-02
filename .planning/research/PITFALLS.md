# Text Editing Pitfalls — Pango-Based System

**Domain:** Text editing on existing Pango rendering
**Researched:** 2026-02-02
**Context:** VGlyph v1.3 — adding cursor, selection, mutation, IME to existing text renderer

## Critical Pitfalls

Mistakes causing rewrites or major correctness issues.

### 1. Byte Index vs Character Index Confusion

**What goes wrong:**
Pango uses UTF-8 byte indices, not character indices. Incrementing index by 1 moves one byte,
not one visible character. Multi-byte UTF-8 (emoji, non-ASCII) causes cursor to land mid-character,
corrupting text on mutation or rendering garbage glyphs.

**Why it happens:**
- Hit testing returns byte index from `pango_layout_xy_to_index()`
- Cursor position API (`pango_layout_index_to_pos()`) takes byte index
- Developer assumes index == character position (works for ASCII, fails elsewhere)
- Text mutation at byte mid-character corrupts UTF-8 sequence

**Consequences:**
- Cursor lands inside emoji/accented characters
- Text insertion corrupts multi-byte sequences
- Delete operations remove partial characters, leaving invalid UTF-8
- Pango emits "Invalid UTF-8 string" warnings, refuses to render

**Prevention:**
- **ALWAYS work in byte indices** when calling Pango APIs
- Use `pango_layout_move_cursor_visually()` for cursor motion (handles grapheme clusters)
- Use Pango's text attribute APIs to query grapheme boundaries
- For character counting/indexing, maintain parallel UTF-8 → byte offset mapping
- **Test early with emoji, accented chars, CJK text** (不 just ASCII)

**Detection:**
- Unit test: cursor motion through "🧑‍🌾" (farmer emoji, 11 bytes, 3 codepoints, 1 grapheme)
- Unit test: delete operation on "é" (NFC vs NFD normalization, 2-4 bytes)
- Runtime: Pango warnings "Invalid UTF-8 string passed to pango_layout_set_text()"
- Visual: cursor appears inside emoji or combining character sequence

**Phase impact:** Foundation phase must establish byte index discipline before mutation.

**Confidence:** HIGH (verified via [Pango Layout docs](https://docs.gtk.org/Pango/class.Layout.html),
[GNOME discourse](https://discourse.gnome.org/t/pango-indexes-to-string-positions-correctly/15814))

---

### 2. Layout Cache Invalidation on Mutation

**What goes wrong:**
Existing VGlyph has layout caching (TTL-based). Text mutation changes content but cache entry
still exists, keyed by old text. Rendering uses stale layout showing pre-mutation text, or worse,
layout metrics mismatch actual text causing out-of-bounds access.

**Why it happens:**
- Cache key doesn't account for text mutability (designed for static rendering)
- Insert/delete doesn't trigger cache eviction for affected layout
- TTL eviction too slow (stale layout persists for seconds/frames)
- Developer forgets cache exists when implementing mutation

**Consequences:**
- Visual: text doesn't update after insert/delete until TTL expires
- Correctness: cursor position queries use stale metrics, wrong pixel coords
- Crash: layout line count mismatch, iterator out of bounds
- Performance: cache hit on wrong data, miss on correct data (cache pollution)

**Prevention:**
- **Invalidate cache entry on ANY text mutation** (insert, delete, replace)
- Consider cache key including content hash or mutation sequence number
- For rich text, invalidate if styled run boundaries change
- Document cache invalidation contract in mutation APIs
- Add debug mode: validate cached layout matches current text (expensive check)

**Detection:**
- Unit test: insert char, immediately query cursor pos — verify uses new text
- Unit test: cache hit counter decreases after mutation (proves invalidation)
- Visual test: type character, verify appears immediately (not on next frame)
- Stress test: rapid insert/delete, check for stale layout or crash

**Phase impact:** Mutation phase must design invalidation strategy before implementing insert/delete.

**Confidence:** MEDIUM (general caching principle, specific to VGlyph's TTL cache design)

---

### 3. IME Marked Text Range Confusion

**What goes wrong:**
macOS NSTextInputClient protocol methods receive ranges in different coordinate systems:
`setMarkedText` uses **absolute document positions**, but developer treats as relative to
marked range. IME composition window appears at wrong location, or text inserted at wrong offset.

**Why it happens:**
- NSTextInputClient docs unclear about absolute vs relative ranges
- `replacementRange` parameter has dual meaning (NSNotFound = replace current marked, else absolute)
- Japanese/Chinese IME reconversion passes non-trivial replacementRange
- Developer tests with English (trivial IME), ships with broken CJK support

**Consequences:**
- IME composition window (candidate list) positioned at wrong screen coords
- Marked text (underlined composition) inserted at wrong document location
- Conversion commits to wrong position, corrupting surrounding text
- CJK users cannot use application (IME completely broken)

**Prevention:**
- **Read "Glaring Hole" article** (see sources) — documents protocol quirks
- Treat all ranges as absolute document positions unless explicitly NSNotFound
- Implement `attributedSubstring(forProposedRange:actualRange:)` correctly (returns document substring)
- Test with Japanese IME reconversion (Kotoeri), not just Roman input
- Maintain marked range state separately from insertion point

**Detection:**
- Test: Japanese IME, type "kanji", convert — verify composition window location
- Test: Chinese IME, select previous text, reconvert — verify replacementRange handling
- Test: Korean IME, rapid typing — verify marked text updates correctly
- Log all NSTextInputClient method calls with ranges during manual testing

**Phase impact:** IME phase must understand protocol before implementing any methods.

**Confidence:** HIGH (verified via [NSTextInputClient docs](https://developer.apple.com/documentation/appkit/nstextinputclient),
[Microsoft blog post](https://learn.microsoft.com/en-us/archive/blogs/rick_schaut/the-glaring-hole-in-the-nstextinputclient-protocol))

---

### 4. Bidirectional Text Cursor Ambiguity

**What goes wrong:**
At boundaries between LTR and RTL text (e.g., "hello שלום"), a single logical position maps to
**two visual positions** (strong and weak cursor). Developer implements only one cursor position,
users cannot access characters at boundaries, or cursor jumps unexpectedly on arrow key.

**Why it happens:**
- Unicode bidirectional algorithm reorders display vs logical positions
- Pango provides `get_cursor_pos()` returning strong AND weak positions
- Developer uses only strong cursor, ignoring weak (or vice versa)
- Arrow key navigation logic assumes visual continuity (doesn't exist at bidi boundaries)

**Consequences:**
- User cannot position cursor at certain boundary positions
- Right arrow moves left visually (or vice versa) — confusing UX
- Selection across LTR/RTL boundary appears fragmented or discontinuous
- Text insertion at boundary goes to unexpected location

**Prevention:**
- **Display both strong and weak cursors** at bidi boundaries (CodeMirror approach)
- Use `pango_layout_move_cursor_visually()` for arrow keys (handles bidi correctly)
- Render selection using Pango's rectangle APIs (handles fragmentation)
- Test with mixed Hebrew/English text, observe strong/weak cursor positions
- Consider simplification: force LTR directionality for v1 (defer RTL to later phase)

**Detection:**
- Visual test: render "hello שלום", position cursor between words, observe dual cursors
- Unit test: arrow key from position 5 (LTR end) — verify moves to position 6 (RTL start)
- Unit test: selection from position 0 to 10 — verify returns correct rectangles (may be non-contiguous)

**Phase impact:** Cursor geometry phase must decide strong/weak strategy before API design.

**Confidence:** HIGH (verified via [Marijn Haverbeke blog](https://marijnhaverbeke.nl/blog/cursor-in-bidi-text.html),
[Pango Layout docs](https://docs.gtk.org/Pango/class.Layout.html))

---

## Moderate Pitfalls

Mistakes causing delays or technical debt.

### 5. Grapheme Cluster Cursor Positioning

**What goes wrong:**
Modern emoji like "🧑‍🌾" (farmer) are multi-codepoint grapheme clusters (person + ZWJ + plant = 11 bytes).
Cursor positioned mid-cluster, text operations split cluster, rendering isolated components (🧑 🌾) instead.

**Why it happens:**
- Developer uses codepoint iteration (rune-by-rune), not grapheme iteration
- Arrow keys increment by 1 codepoint, landing inside ZWJ sequence
- Combining characters (accents) treated as separate cursor positions

**Prevention:**
- Use Pango's `pango_break()` or `PangoLogAttr` for grapheme boundaries
- Cursor motion must skip to next grapheme, not next codepoint
- Test with emoji: "👨‍👩‍👧‍👦" (family, 25 bytes), "🇺🇸" (flag, 8 bytes)
- Test with combining characters: "e\u0301" (é as base + accent)

**Detection:**
- Test: arrow key through "🧑‍🌾", should move 11 bytes, not 4
- Test: delete "🧑‍🌾", should remove entire cluster, not just 🧑

**Phase impact:** Cursor motion phase must use grapheme-aware APIs.

**Confidence:** HIGH (verified via [Mitchell Hashimoto blog](https://mitchellh.com/writing/grapheme-clusters-in-terminals),
[Pango LogAttr docs](https://docs.gtk.org/Pango/struct.LogAttr.html))

---

### 6. Selection Across Styled Runs

**What goes wrong:**
VGlyph has rich text with styled runs (font, size, color). Selection spans multiple runs,
highlighting drawn per-run with gaps at run boundaries, or style applied to selection affects
wrong run.

**Why it happens:**
- Selection rectangle calculation per-run, not accounting for inter-run spacing
- Run boundary detection missing — treats styled text as monolithic
- Style application on selection doesn't preserve non-selected portions of runs

**Prevention:**
- Pango handles multi-run selection via `pango_layout_index_to_pos()` (works across runs)
- Ensure selection rectangles merged across runs (union of per-run rects)
- Test: select from middle of bold run into italic run, verify continuous highlight
- Document run boundary behavior for mutation APIs

**Detection:**
- Visual test: select "**bold**italic" (bold then italic), observe highlight continuity
- Unit test: selection rect count — should return merged rects, not per-run

**Phase impact:** Selection phase must test multi-run scenarios early.

**Confidence:** MEDIUM (general rich text principle, specific to VGlyph's run implementation)

---

### 7. IME Composition Window Coordinate System

**What goes wrong:**
NSTextInputClient's `firstRectForCharacterRange` must return screen coordinates (NSRect in screen space),
but developer returns window-relative or view-relative coords. IME candidate window appears at wrong
screen location (off-screen or wrong monitor).

**Why it happens:**
- Coordinate system confusion (view → window → screen transformations)
- VGlyph operates in view-local coords, IME needs screen-global
- Multi-monitor setups amplify coordinate bugs (wrong display)

**Prevention:**
- Use `convertToScreen:` APIs to transform view coords to screen space
- Test on multi-monitor setup (primary + secondary display)
- Test with IME active, verify candidate window follows cursor
- Handle HiDPI scaling (Retina display coordinate doubling)

**Detection:**
- Visual test: Japanese IME, type on secondary monitor, verify candidate window location
- Test: cursor at bottom of screen, verify IME window doesn't go off-screen (system clips)

**Phase impact:** IME phase must implement coordinate transform correctly.

**Confidence:** MEDIUM (NSTextInputClient requirement, specifics depend on v-gui integration)

---

### 8. Undo/Redo with Rich Text Mutations

**What goes wrong:**
Text mutation history (undo stack) stores text content but not styled run boundaries. Undo restores
old text but loses styling, or redo applies new text with wrong styles.

**Why it happens:**
- Undo implementation captures text string only, not PangoAttrList
- Styled run offsets (byte indices) invalidated by text insertion/deletion
- Developer tests undo with plain text (works), ships with broken rich text undo

**Prevention:**
- Undo state must include: text + attr list + run boundaries
- Consider serializing PangoAttrList or maintaining parallel style structure
- Update run offsets on text mutation (insert/delete shifts indices)
- Test: bold text, undo, redo — verify bold preserved

**Detection:**
- Test: type "**bold**", undo, redo — verify bold styling returns
- Test: delete inside styled run, undo — verify run boundaries restored

**Phase impact:** Mutation phase should design undo strategy before implementing insert/delete.

**Confidence:** MEDIUM (general undo principle, specific to Pango attr list management)

---

## Minor Pitfalls

Mistakes causing annoyance but fixable.

### 9. Cursor Blink Phase on Focus

**What goes wrong:**
Cursor blink timer starts at random phase on focus, sometimes cursor invisible initially (bad UX).

**Why it happens:**
- Blink timer started without forcing visible state first
- Focus event doesn't reset blink phase to "visible"

**Prevention:**
- On focus: show cursor immediately, then start blink timer
- On focus lost: hide cursor (no blinking when unfocused)

**Detection:**
- Manual test: click into text field 20 times, cursor should always appear immediately

**Phase impact:** v-gui integration phase.

**Confidence:** HIGH (common text editor UX pattern)

---

### 10. Selection Rendering Z-Order

**What goes wrong:**
Selection highlight drawn after text, obscures glyphs (especially with opaque highlight color).

**Why it happens:**
- Rendering order: text first, selection second (wrong)
- Alpha blending wrong direction (highlight over text instead of under)

**Prevention:**
- Render order: selection highlight, then text glyphs
- Use semi-transparent selection color for highlight visibility

**Detection:**
- Visual test: select text, verify glyphs visible over highlight

**Phase impact:** Selection rendering phase.

**Confidence:** HIGH (standard text rendering practice)

---

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation |
|-------|---------------|------------|
| Foundation | Byte index confusion (1) | Use Pango cursor motion APIs, test with emoji early |
| Cursor geometry | Bidirectional ambiguity (4) | Decide strong/weak strategy, use `get_cursor_pos()` correctly |
| Cursor motion | Grapheme clusters (5) | Use PangoLogAttr for boundaries, test with ZWJ emoji |
| Selection | Multi-run highlighting (6) | Test across styled runs, verify rect merging |
| Mutation | Cache invalidation (2) | Design invalidation strategy first, test immediately |
| Mutation | Undo/redo with styles (8) | Capture attr list in undo state, test with rich text |
| IME | Range confusion (3) | Read protocol docs carefully, test with Japanese IME |
| IME | Coordinate system (7) | Test on multi-monitor, verify screen space coords |
| v-gui integration | Cursor blink phase (9) | Reset timer on focus, show cursor immediately |
| Rendering | Selection z-order (10) | Render highlight before text |

## Testing Strategy

**Minimal test corpus for pitfall detection:**
```
ASCII:        "hello world"
Emoji:        "hello 🧑‍🌾 world"  (ZWJ sequence)
Flag:         "🇺🇸"               (regional indicators)
Combining:    "é"                 (e + combining acute)
Bidi:         "hello שלום"        (LTR + RTL)
CJK:          "你好 world"        (multi-byte, IME test)
Multi-run:    "**bold**italic"   (styled text)
```

**Critical manual tests:**
- Japanese IME: type "kanji", convert, verify composition window
- Multi-monitor: cursor on secondary display, verify IME follows
- Rapid typing: insert 100 chars fast, verify cache invalidates, no lag
- Undo/redo: style text, undo, redo — verify styles preserved

## Open Questions

- Defer bidirectional text to post-v1.3? (simplify by forcing LTR)
- Undo granularity: per-character or per-word? (affects undo stack size)
- IME scope: macOS only for v1.3, or Linux/Windows too? (IBus/TSF complexity)

## Sources

**HIGH confidence (official docs, authoritative sources):**
- [Pango Layout class](https://docs.gtk.org/Pango/class.Layout.html) — byte index APIs
- [Pango LogAttr](https://docs.gtk.org/Pango/struct.LogAttr.html) — grapheme boundaries
- [NSTextInputClient](https://developer.apple.com/documentation/appkit/nstextinputclient) — IME protocol
- [Microsoft: Glaring Hole in NSTextInputClient](https://learn.microsoft.com/en-us/archive/blogs/rick_schaut/the-glaring-hole-in-the-nstextinputclient-protocol) — protocol quirks
- [Marijn Haverbeke: Cursor in Bidi Text](https://marijnhaverbeke.nl/blog/cursor-in-bidi-text.html) — bidirectional challenges
- [Mitchell Hashimoto: Grapheme Clusters in Terminals](https://mitchellh.com/writing/grapheme-clusters-in-terminals) — emoji handling

**MEDIUM confidence (community/implementation discussions):**
- [GNOME Discourse: Pango Indexes](https://discourse.gnome.org/t/pango-indexes-to-string-positions-correctly/15814)
- [Mozilla Bug 335810](https://bugzilla.mozilla.org/show_bug.cgi?id=335810) — Pango cursor bugs
- [Mozilla Bug 875674](https://bugzilla.mozilla.org/show_bug.cgi?id=875674) — NSTextInputClient implementation
- [xi-editor IME Issue](https://github.com/xi-editor/xi-mac/issues/18) — IME complexity discussion
- [TinyMCE: Undo Function Handling](https://www.tiny.cloud/blog/undo-function-handling/) — undo/redo patterns

**LOW confidence (unverified WebSearch findings):**
- Cache invalidation patterns — general principle, not Pango-specific
- Multi-monitor coordinate systems — NSTextInputClient requirement, specifics TBD with v-gui integration
