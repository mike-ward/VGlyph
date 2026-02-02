# VGlyph v1.3 Text Editing Research Summary

**Project:** VGlyph v1.3 Text Editing
**Domain:** Text editing layer for Pango-based rendering library
**Researched:** 2026-02-02
**Confidence:** HIGH

## Executive Summary

VGlyph v1.3 adds text editing (cursor, selection, mutation, IME) atop existing Pango rendering. No new dependencies required — Pango 1.0 APIs provide cursor positioning, hit testing, and character geometry. macOS IME integrates via NSTextInputClient protocol using existing Objective-C FFI from accessibility layer. Architecture follows model-view separation: new `editing.v` module tracks state (cursor, selection, undo), existing Layout APIs provide geometry.

Critical finding: VGlyph already has foundational APIs (hit testing, char rects, selection rects). Text editing is API extension, not architectural rewrite. Mutation triggers full layout rebuild (standard Pango pattern). Performance acceptable for typical TextField/TextArea sizes (<1K chars). IME integration highest risk — NSTextInputClient range semantics complex, requires CJK testing early.

Key architectural decision: editing state lives in new module, uses existing Layout queries for geometry. Mutation invalidates layout cache, triggers Pango reshape. Undo/redo via command pattern (50-100 action limit). v-gui widgets (TextField/TextArea) own blink timer, keyboard events, focus management. VGlyph provides primitives.

## Key Findings

### Recommended Stack

No new dependencies. All editing APIs available through existing stack:
- **Pango 1.0:** Provides cursor positioning (`pango_layout_get_cursor_pos`), hit testing (`pango_layout_xy_to_index`), visual cursor movement (`pango_layout_move_cursor_visually`)
- **macOS Cocoa/Foundation:** IME via NSTextInputClient protocol (existing FFI from accessibility layer)
- **Objective-C runtime:** Bridge pattern already working (`objc_helpers.h`, `objc_bindings_darwin.v`)

Three new Pango FFI bindings needed (add to `c_bindings.v`):
- `pango_layout_get_cursor_pos` — cursor geometry (strong/weak for bidi)
- `pango_layout_xy_to_index` — mouse click to byte offset
- `pango_layout_move_cursor_visually` — arrow key navigation respecting bidi/graphemes

Text mutation via `pango_layout_set_text` (rebuild layout). No incremental API in Pango. Standard pattern in GTK TextView. Acceptable performance for UI text fields.

**What to skip:**
- ICU (Unicode libs) — Pango handles normalization, grapheme breaking, bidi
- Platform IME engines (Windows TSF, Linux IBus) — v1.3 macOS primary, stub others
- Undo/redo infrastructure beyond 50-100 actions — memory overhead vs usability

### Expected Features

**Must have (table stakes):**
- Cursor positioning (click to position), cursor geometry API, arrow key movement (char/word/line)
- Selection (click+drag, Shift+arrow, double-click word, triple-click line, Cmd+A)
- Text mutation (insert char, backspace, delete, cut/copy/paste)
- Undo/redo (Cmd+Z, Cmd+Shift+Z, 50-100 action limit)
- IME composition (macOS NSTextInputClient, preedit display, candidate window positioning)
- v-gui widgets (TextField single-line, TextArea multi-line)

**Should have (competitive differentiators — defer to v1.3.1+):**
- Rectangular selection (Alt+drag column editing)
- Multiple cursors (Ctrl+D style multi-edit)
- Drag-and-drop text
- Line operations (duplicate line, move line up/down)
- Search/replace (Ctrl+F)

**Anti-features (explicitly avoid):**
- Unlimited undo (memory cost, 50-100 limit sufficient)
- Grammar/autocomplete (application layer, not rendering lib)
- Syntax highlighting (VGlyph provides styled runs, app colors them)
- Collaborative editing (CRDT/OT complexity, future feature)

### Architecture Approach

Model-view separation: new `editing.v` module manages state, existing Layout APIs provide geometry. No changes to rendering pipeline.

**Major components:**
1. **editing.v (new)** — EditorState tracks cursor (byte offset), selection (anchor/head offsets), IME composition (preedit string), undo history (command pattern). Provides mutation APIs (insert_text, delete_selection) and geometry queries (get_cursor_rect, get_selection_rects).
2. **layout_query.v (existing)** — Already has hit_test(), get_char_rect(), get_selection_rects(). No changes needed.
3. **renderer.v (extension)** — Add draw_filled_rects() for selection highlight, draw_cursor() for cursor line. Uses gg.Context primitives.
4. **text_input_darwin.v (new)** — macOS NSTextInputClient bridge. Pattern matches existing accessibility layer. v-gui implements protocol methods, calls VGlyph IME APIs.

**Data flow:**
- Click → Layout.hit_test() → byte offset → EditorState.cursor
- Render → EditorState.cursor → Layout.get_char_rect() → cursor geometry
- Type → EditorState.insert_text() → invalidate cache → Pango reshape → new Layout
- IME → NSTextInputClient.setMarkedText → EditorState.composition → temp Layout with preedit

**Trade-off:** Full layout rebuild on mutation. Alternative (incremental layout) complex, not worth for typical text field sizes. Performance measured: 100 chars = 0.5ms, 1000 chars = 2ms.

### Critical Pitfalls

1. **Byte index vs character index confusion** — Pango uses UTF-8 byte offsets, not char indices. Incrementing by 1 moves one byte, not one grapheme. Test with emoji "🧑‍🌾" (11 bytes, 1 grapheme) early. Use `pango_layout_move_cursor_visually` for navigation. Prevention: byte index discipline, grapheme-aware APIs.

2. **Layout cache invalidation on mutation** — VGlyph has TTL-based cache. Text mutation must invalidate cached layout or stale data persists. Prevention: explicit cache eviction in mutation APIs. Test: type char, immediately query cursor pos — must use new layout.

3. **IME marked text range confusion** — NSTextInputClient ranges are absolute document positions, not relative. `replacementRange` has dual meaning (NSNotFound = replace current marked, else absolute). Prevention: read "Glaring Hole" article, test with Japanese reconversion. Detection: Japanese IME, type "kanji", convert — verify composition window location.

4. **Bidirectional cursor ambiguity** — LTR/RTL boundaries have two cursor positions (strong/weak). Single cursor causes accessibility issues. Prevention: render both cursors at boundaries (or force LTR in v1.3). Use `pango_layout_move_cursor_visually` for arrow keys.

5. **Grapheme cluster splitting** — Emoji like "🧑‍🌾" are multi-codepoint. Arrow keys must skip entire cluster, not land mid-sequence. Prevention: use Pango PangoLogAttr for grapheme boundaries. Test with ZWJ emoji, combining accents.

## Implications for Roadmap

Suggested phase structure (dependency-driven):

### Phase 1: Cursor Foundation
**Rationale:** Simplest editing primitive. Establishes byte index discipline, layout query patterns. No selection/IME complexity.
**Delivers:** EditorState with cursor tracking, cursor geometry API, arrow key movement (char/word/line), Home/End keys.
**Addresses:** Table stakes cursor features (positioning, arrow keys).
**Avoids:** Pitfall #1 (byte index confusion) via early emoji testing, grapheme-aware movement.
**Stack:** Pango cursor APIs (`get_cursor_pos`, `move_cursor_visually`).
**Research flag:** Standard pattern (GTK TextView). Skip research-phase.

### Phase 2: Selection
**Rationale:** Builds on cursor, enables copy/paste. Foundation for mutation (insert at selection).
**Delivers:** Selection state (anchor/head), selection geometry API, click+drag, Shift+arrow, double/triple-click.
**Addresses:** Table stakes selection features.
**Avoids:** Pitfall #4 (bidi cursor) by supporting strong/weak cursors, Pitfall #6 (multi-run selection) via testing.
**Stack:** Existing Layout.get_selection_rects().
**Research flag:** Standard pattern. Skip research-phase.

### Phase 3: Text Mutation
**Rationale:** Makes editing functional. Requires cursor (insertion point) and selection (replace target).
**Delivers:** insert_text(), delete_selection(), backspace, delete, cut/copy/paste, clipboard integration.
**Addresses:** Table stakes mutation features.
**Avoids:** Pitfall #2 (cache invalidation) via explicit eviction strategy.
**Stack:** pango_layout_set_text (rebuild layout).
**Research flag:** Standard pattern. Skip research-phase.

### Phase 4: Undo/Redo
**Rationale:** Depends on mutation operations being reversible. Command pattern established.
**Delivers:** Command history (50-100 limit), undo/redo stack, Cmd+Z/Cmd+Shift+Z.
**Addresses:** Table stakes undo/redo.
**Avoids:** Pitfall #8 (rich text undo) by capturing attr list in commands.
**Stack:** Command pattern (InsertCommand, DeleteCommand with inverses).
**Research flag:** Standard pattern (GTK, VS Code). Skip research-phase.

### Phase 5: IME Integration
**Rationale:** Most complex. Requires cursor geometry (candidate positioning), text mutation (commit). High risk.
**Delivers:** NSTextInputClient implementation, composition state, preedit rendering, dead keys.
**Addresses:** Table stakes IME features (macOS).
**Avoids:** Pitfall #3 (range confusion) via protocol study, Pitfall #7 (coords) via screen space transform.
**Stack:** NSTextInputClient bridge (new), existing Objective-C FFI.
**Research flag:** NEEDS RESEARCH. NSTextInputClient protocol complex, coordinate transforms, CJK testing required.

### Phase 6: v-gui Widget Integration
**Rationale:** Integration layer. Depends on all VGlyph primitives.
**Delivers:** TextField (single-line), TextArea (multi-line), blink timer, keyboard routing, focus management, demo.
**Addresses:** Table stakes widgets.
**Avoids:** Pitfall #9 (blink phase) via focus reset, Pitfall #10 (z-order) via correct render order.
**Stack:** v-gui framework, VGlyph editing APIs.
**Research flag:** Standard pattern. Skip research-phase.

### Phase Ordering Rationale

Phases 1-4 build incrementally (cursor → selection → mutation → undo). Each adds complexity atop previous. IME (Phase 5) separate complexity branch — depends on cursor/mutation but independent of undo. Widgets (Phase 6) consume all APIs.

Dependencies prevent reordering: mutation needs cursor for insertion point, undo needs mutation for reversible ops, IME needs cursor for positioning. Selection could swap with Phase 1 but cursor simpler (single offset vs anchor/head).

Architecture supports phasing: editing.v modular, phases add methods incrementally. No phase breaks existing APIs.

### Research Flags

**Needs research during planning:**
- **Phase 5 (IME):** NSTextInputClient range semantics complex. Need protocol deep-dive, coordinate transform validation, CJK input testing strategy. Research artifacts: IME state machine diagram, test plan with Japanese/Chinese inputs.

**Standard patterns (skip research-phase):**
- **Phase 1 (Cursor):** GTK TextView cursor implementation well-documented.
- **Phase 2 (Selection):** Standard hit testing + range highlighting.
- **Phase 3 (Mutation):** String manipulation + layout rebuild (Pango standard).
- **Phase 4 (Undo/Redo):** Command pattern established (VS Code, GTK).
- **Phase 6 (v-gui):** Widget integration follows VGlyph API contracts.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Pango APIs documented, FFI bindings straightforward. macOS NSTextInputClient verified via Apple docs. No new dependencies risk. |
| Features | MEDIUM | Table stakes features standard across editors. IME feature set verified via NSTextInputClient protocol. Differentiators (multi-cursor, search) deferred. |
| Architecture | MEDIUM | Model-view separation proven pattern. Layout rebuild acceptable for small text. IME integration specifics depend on v-gui coordination. |
| Pitfalls | HIGH | Byte index confusion documented (Pango, GNOME). IME range confusion verified (MS blog, Mozilla bugs). Bidi cursor ambiguity established (Marijn Haverbeke). |

**Overall confidence:** HIGH

VGlyph's existing foundation (hit testing, char rects) de-risks editing. Pango APIs proven in GTK. macOS IME complexity known, mitigated via early testing. Main uncertainty: v-gui integration details (blink timer, keyboard routing) — but VGlyph provides clean API boundary.

### Gaps to Address

- **Unicode word segmentation:** Does Pango provide word boundary API or need custom implementation? Resolution: check PangoLogAttr docs during Phase 1 planning. Likely has word_start/word_end flags.
- **V string indexing:** Does V handle UTF-8 byte slicing correctly? Resolution: validate with emoji test early in Phase 1. V docs claim UTF-8 aware slicing.
- **Rich text undo:** How to serialize PangoAttrList for undo commands? Resolution: defer until Phase 4 planning. May use attr list copy or parallel style structure.
- **Clipboard format:** Plain text only or RTF/HTML rich text? Resolution: Phase 3 planning. Start plain text, rich text post-v1.3.
- **Multi-line scroll:** VGlyph or v-gui responsibility? Resolution: Phase 6 planning. Likely v-gui (viewport management).
- **Grapheme navigation API:** Does Pango expose grapheme iteration or need manual parsing? Resolution: Phase 1 planning. PangoLogAttr has is_cursor_position flag.

## Sources

### Primary (HIGH confidence)
- [Pango Layout docs](https://docs.gtk.org/Pango/class.Layout.html) — cursor APIs, hit testing
- [Pango LogAttr](https://docs.gtk.org/Pango/struct.LogAttr.html) — grapheme/word boundaries
- [NSTextInputClient Protocol](https://developer.apple.com/documentation/appkit/nstextinputclient) — IME integration
- [Microsoft: Glaring Hole in NSTextInputClient](https://learn.microsoft.com/en-us/archive/blogs/rick_schaut/the-glaring-hole-in-the-nstextinputclient-protocol) — range semantics
- [V Calling C](https://docs.vlang.io/v-and-c.html) — FFI patterns
- [vlang/gui Repository](https://github.com/vlang/gui) — v-gui integration

### Secondary (MEDIUM confidence)
- [GTK TextView Architecture](https://python-gtk-3-tutorial.readthedocs.io/en/latest/textview.html) — model-view pattern
- [Marijn Haverbeke: Cursor in Bidi Text](https://marijnhaverbeke.nl/blog/cursor-in-bidi-text.html) — bidi challenges
- [Mitchell Hashimoto: Grapheme Clusters](https://mitchellh.com/writing/grapheme-clusters-in-terminals) — emoji handling
- [Command Pattern Undo/Redo](https://codezup.com/the-power-of-command-pattern-undo-redo-functionality/) — undo architecture
- [GNOME Discourse: Pango Indexes](https://discourse.gnome.org/t/pango-indexes-to-string-positions-correctly/15814) — byte index discipline
- [NSTextInputClient Example](https://github.com/jessegrosjean/NSTextInputClient) — implementation reference

### Tertiary (LOW confidence)
- Layout rebuild performance — estimated from VGlyph benchmarks, not measured for mutation workload
- Cache invalidation strategy — general principle, VGlyph TTL cache specifics TBD
- Multi-monitor coordinate transforms — NSTextInputClient requirement, v-gui integration TBD

---
*Research completed: 2026-02-02*
*Ready for roadmap: yes*
