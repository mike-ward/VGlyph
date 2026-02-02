# Feature Landscape: Text Editing

**Domain:** Text editing in GUI text rendering libraries
**Researched:** 2026-02-02
**Project:** VGlyph v1.3
**Confidence:** MEDIUM (WebSearch + official docs, macOS NSTextInputClient verified)

## Executive Summary

Text editing requires four core systems: cursor (positioning, movement, visual), selection
(character/word/line modes, highlighting), mutation (insert/delete/replace with undo/redo), and IME
(composition for international input). Industry standard behaviors are well-established - double-click
selects word, triple-click selects line/paragraph, arrow keys move cursor with modifiers for
word/line jumps.

VGlyph already has foundation APIs (hit testing, character rect queries) that map directly to cursor
and selection geometry. Text editing adds state management (cursor position, selection range) and
mutation operations. IME integration on macOS requires NSTextInputClient protocol implementation.

Three use cases drive requirements: simple input fields (single-line, Enter submits), rich text
editors (formatted spans, mixed fonts), code editors (line numbers, monospace, syntax highlighting).
All share core editing features but differ in visual presentation and keyboard behavior.

## Table Stakes

Features users expect from text editing. Missing = product feels broken or unusable.

### Cursor Features

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Cursor positioning** | Click sets cursor | Low | Hit testing (existing) | VGlyph has hit_test_point |
| **Cursor → rect API** | Draw cursor at position | Low | Character rect (existing) | VGlyph has character_rect |
| **Arrow key movement** | Left/right/up/down | Low | Layout line info | Character-by-character navigation |
| **Home/End keys** | Line start/end | Low | Line boundaries | Standard keyboard expectation |
| **Ctrl+Arrow (macOS Cmd)** | Word boundaries | Medium | Word segmentation | Unicode UAX#29 word breaks |
| **Cursor blink** | Visual feedback | Low | GUI timer | 500-530ms standard, v-gui responsibility |
| **Cursor vertical positioning** | Same column when moving up/down | Medium | Column memory | Preserve X position across lines |

**Rationale:** Standard editing expectations across all platforms. Users expect cursor to respond to
clicks and arrow keys immediately. Blink rate 500-530ms is accessibility standard ([Microsoft
docs](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/dnacc/flashing-user-interface-and-the-getcaretblinktime-function)).

### Selection Features

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Click + drag selection** | Visual selection | Low | Hit testing | Standard mouse behavior |
| **Shift+arrow selection** | Keyboard selection | Low | Cursor movement | Extend selection from anchor |
| **Double-click → word** | Quick word select | Medium | Word boundaries | Standard across all editors |
| **Triple-click → line/paragraph** | Quick line select | Medium | Line boundaries | Firefox/Word: paragraph, others: line |
| **Shift+Home/End** | Select to line start/end | Low | Cursor movement | Extends selection |
| **Ctrl+A (Cmd+A)** | Select all | Low | Text boundaries | Universal shortcut |
| **Selection → rects API** | Visual highlighting | Low | Character rects | VGlyph has character_rect |
| **Selection rendering** | Blue highlight (platform theme) | Low | GUI rendering | v-gui responsibility |

**Rationale:** Standard selection behaviors universal across editors. Double-click word selection and
triple-click line selection documented standard ([Wikipedia
triple-click](https://en.wikipedia.org/wiki/Triple-click)). Selection highlighting uses platform
theme colors for consistency.

### Mutation Features

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Insert character at cursor** | Typing inserts text | Low | Cursor position | Replace selection if active |
| **Backspace** | Delete before cursor | Low | Cursor position | Or delete selection |
| **Delete** | Delete after cursor | Low | Cursor position | Or delete selection |
| **Cut (Ctrl+X/Cmd+X)** | Remove to clipboard | Medium | Clipboard API | System clipboard integration |
| **Copy (Ctrl+C/Cmd+C)** | Copy to clipboard | Low | Clipboard API | Preserves text |
| **Paste (Ctrl+V/Cmd+V)** | Insert from clipboard | Medium | Clipboard API | Replace selection if active |
| **Undo (Ctrl+Z/Cmd+Z)** | Reverse last action | High | Command history | Command pattern or memento |
| **Redo (Ctrl+Y/Cmd+Shift+Z)** | Reapply undone action | High | Command history | Redo stack cleared on new edit |

**Rationale:** Basic mutation operations are universal editing expectations. Clipboard operations
([web.dev clipboard
API](https://web.dev/patterns/clipboard/copy-text)) standard across platforms. Undo/redo uses command
pattern ([Command pattern
article](https://codezup.com/the-power-of-command-pattern-undo-redo-functionality/)) - each edit is
reversible command. Redo stack cleared when new edit happens after undo.

### IME Features (macOS Primary)

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Composition window** | Visual feedback for IME | Medium | NSTextInputClient | Underlined text during composition |
| **Composition text display** | Show uncommitted text | Medium | NSTextInputClient | insertText vs setMarkedText |
| **Candidate selection** | Choose from candidates | Medium | NSTextInputClient | attributedSubstringForProposedRange |
| **Composition commit** | Finalize input | Low | NSTextInputClient | Replace marked text with final |
| **Dead key support** | Accent + letter = accented | Medium | NSTextInputClient | Compose key sequences |
| **IME positioning** | Candidate window near cursor | Low | Cursor rect | validAttributesForMarkedText |

**Rationale:** IME essential for international text input (Chinese, Japanese, Korean, Vietnamese).
macOS NSTextInputClient protocol standard ([Apple
docs](https://developer.apple.com/documentation/appkit/nstextinputclient)). Composition shows
uncommitted text with underline, candidates appear in popup near cursor. Dead keys ([Wikipedia dead
key](https://en.wikipedia.org/wiki/Dead_key)) combine accent + base character (e.g., ´ + e = é).
Recent VS Code bug report Jan 2026 shows dead keys still active concern ([VS Code
#288972](https://github.com/microsoft/vscode/issues/288972)).

## Differentiators

Advanced editing features that set editors apart. Not expected by all users, but valued when present.

### Enhanced Selection

| Feature | Value Proposition | Complexity | Impact | Use Cases |
|---------|-------------------|------------|--------|-----------|
| **Rectangular selection** | Column editing | Medium | High for code | Alt+drag in VS Code |
| **Multiple cursors** | Edit many places at once | High | High for code | Ctrl+D in VS Code |
| **Expand selection** | Smart expand to scope | Medium | Medium | Alt+Shift+→ semantic expansion |
| **Select occurrences** | Find all instances | Medium | High | Ctrl+D in VS Code |

**Rationale:** Power user features common in modern editors ([VS Code
selections](https://learn.microsoft.com/en-us/visualstudio/ide/finding-and-replacing-text?view=visualstudio)).
Rectangular selection useful for column data. Multiple cursors high productivity for refactoring.

### Advanced Mutation

| Feature | Value Proposition | Complexity | Impact | Use Cases |
|---------|-------------------|------------|--------|-----------|
| **Drag and drop text** | Move text visually | Medium | Medium | Mouse-centric editing |
| **Smart delete** | Delete word/line | Low | Medium | Ctrl+Backspace/Delete |
| **Duplicate line** | Fast line copying | Low | Medium | Ctrl+D in many editors |
| **Move line up/down** | Reorder without cut/paste | Medium | Medium | Alt+↑/↓ in VS Code |
| **Auto-indent** | Maintain indentation | Medium | High for code | Language-specific rules |

**Rationale:** Drag-drop text standard in desktop editors ([EmEditor
drag-drop](https://www.emeditor.com/text-editor-features/more-features/drag-drop/)). Smart delete
extends Backspace/Delete to word boundaries. Line operations common in code editors.

### Rich Text Specific

| Feature | Value Proposition | Complexity | Impact | Use Cases |
|---------|-------------------|------------|--------|-----------|
| **Format selection** | Apply bold/italic/color | Medium | High | Rich text editors |
| **Span-aware selection** | Respect formatting boundaries | Medium | Medium | Don't split styled runs |
| **Style preservation on paste** | Keep formatting | High | Medium | Rich text clipboard |
| **Format painter** | Copy formatting to another region | Medium | Medium | Word-style formatting copy |

**Rationale:** Rich text requires selection to respect styled runs ([Compose Rich
Editor](https://mohamedrejeb.github.io/compose-rich-editor/getting_started/)). Format selection
changes attributes on selected range. VGlyph already has styled runs - editing must preserve
run boundaries when possible.

### Code Editor Specific

| Feature | Value Proposition | Complexity | Impact | Use Cases |
|---------|-------------------|------------|--------|-----------|
| **Line numbers gutter** | Reference specific lines | Low | High | Code navigation |
| **Bracket matching** | Show matching pairs | Medium | High | Code structure |
| **Auto-close brackets** | Type { gets } | Low | Medium | Reduces errors |
| **Comment toggle** | Toggle line/block comments | Medium | Medium | Ctrl+/ common |
| **Code folding** | Collapse sections | High | Medium | Large files |

**Rationale:** Code editors need line numbers ([CodeMirror
gutter](https://github.com/codemirror/gutter)) for debugging references. Bracket matching shows
structure. Auto-close reduces syntax errors. For v1.3, line numbers are table stakes, advanced
features defer.

### Search and Replace

| Feature | Value Proposition | Complexity | Impact | Use Cases |
|---------|-------------------|------------|--------|-----------|
| **Find in text** | Locate string | Medium | High | All use cases |
| **Find next/previous** | Navigate matches | Low | High | F3/Shift+F3 standard |
| **Replace** | Substitute text | Medium | High | Editing workflow |
| **Regex support** | Pattern matching | High | Medium | Power users |
| **Find in selection** | Scoped search | Low | Low | Refine search |

**Rationale:** Find/replace fundamental editing tool ([VS Code
find](https://learn.microsoft.com/en-us/visualstudio/ide/finding-and-replacing-text?view=visualstudio)).
Ctrl+F standard across platforms. Regex adds power but complexity. For v1.3, basic find likely
deferred - not core editing.

## Anti-Features

Features to explicitly NOT build in v1.3. Common mistakes or premature optimization.

| Anti-Feature | Why Avoid | What Instead | Notes |
|--------------|-----------|--------------|-------|
| **Multi-level undo history (>100)** | Memory overhead, UX confusion | 50-100 limit | Research shows users rarely undo >20 steps |
| **Persistent undo across sessions** | Complex serialization | Session-only | Most editors don't persist |
| **Grammar checking** | Out of scope for rendering lib | External service | Belongs in application layer |
| **Auto-complete** | Context-dependent, language-specific | External | Not VGlyph responsibility |
| **Syntax highlighting** | Already exists via styled runs | Use VGlyph run API | VGlyph provides rendering, app provides colors |
| **Line wrapping logic** | Already exists in Pango | Use Pango layout | VGlyph wraps via Pango width |
| **Collaborative editing** | Requires CRDT or OT | Future feature | Complex distributed systems problem |
| **Custom cursor shapes** | Platform inconsistency | Standard I-beam | Accessibility concern |
| **Selection handles (mobile)** | Desktop-first for v1.3 | Future mobile support | macOS primary target |
| **Voice input** | Platform service | External | macOS dictation separate |

**Rationale:**
- **Undo limit:** Research shows command pattern with stack ([Command
  pattern](https://codezup.com/the-power-of-command-pattern-undo-redo-functionality/)). Unlimited
  undo has memory cost. 50-100 reasonable.
- **Persistent undo:** Adds serialization complexity. Most editors (Notepad, TextEdit) don't persist
  undo across sessions.
- **Grammar/autocomplete:** Application features, not rendering library responsibility. VGlyph
  provides text rendering, v-gui TextField/TextArea provide higher-level features.
- **Syntax highlighting:** VGlyph already supports styled runs (PROJECT.md). Application passes
  colored runs to VGlyph. Not VGlyph's job to parse code.
- **Line wrapping:** Pango handles wrapping when max_width set. VGlyph uses Pango layout.
- **Collaborative editing:** Requires conflict resolution algorithms (CRDT/OT). Way beyond v1.3
  scope. Future feature if needed.
- **Custom cursors:** Accessibility issue - screen readers expect standard cursor. Platform provides
  I-beam cursor.
- **Selection handles:** Mobile pattern (iOS/Android drag handles). macOS primary for v1.3. Mobile
  support future.
- **Voice input:** macOS dictation is system service. NSTextInputClient handles. Not custom
  implementation.

## Feature Dependencies

```
Foundation (Existing VGlyph APIs)
  ├─> hit_test_point() → cursor positioning
  ├─> character_rect() → cursor rendering
  └─> character_rect() → selection highlighting

Cursor System
  ├─> Cursor position state (index into text)
  ├─> Cursor → rect API (position → geometry)
  ├─> Arrow key movement (character/word/line)
  └─> Column memory for vertical movement

Selection System
  ├─> Selection state (start, end indices)
  ├─> Selection → rects API (range → geometries)
  ├─> Click+drag handling (hit test)
  ├─> Shift+arrow handling (extend selection)
  ├─> Double/triple-click (word/line boundaries)
  └─> Word boundary detection (Unicode UAX#29)

Mutation System
  ├─> Text buffer (mutable string)
  ├─> Insert/delete operations (at cursor/selection)
  ├─> Clipboard integration (system API)
  ├─> Undo/redo stack (command pattern)
  └─> Selection deletion (clear before insert)

IME System (macOS)
  ├─> NSTextInputClient protocol
  ├─> Composition state (marked text range)
  ├─> Candidate window positioning (cursor rect)
  └─> Dead key handling (character composition)

v-gui Integration
  ├─> TextField widget (single-line)
  ├─> TextArea widget (multi-line)
  ├─> Blink timer (cursor animation)
  ├─> Keyboard event routing (arrow keys, modifiers)
  ├─> Focus management (which widget is active)
  └─> Theme colors (selection highlight, cursor color)
```

**Implementation Order:**
1. **Cursor system** → foundation for all editing
2. **Selection system** → depends on cursor movement
3. **Mutation system** → depends on cursor + selection
4. **IME system** → depends on cursor positioning + mutation
5. **v-gui integration** → depends on all VGlyph APIs

## Use Case Specific Requirements

### Simple Input Fields (Single-Line)

| Feature | Requirement | Differs From Multi-Line | Notes |
|---------|-------------|-------------------------|-------|
| **Enter key** | Submit form, don't insert newline | Multi-line inserts newline | Standard behavior ([MDN aria-multiline](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-multiline)) |
| **Arrow up/down** | Move cursor to start/end | Multi-line moves between lines | Or navigate history (URL bar) |
| **Line wrapping** | No visual wrapping | Multi-line wraps | Horizontal scroll instead |
| **Max length** | Enforce character limit | Optional in multi-line | Validation boundary |
| **Placeholder text** | Show when empty | Same in multi-line | "Enter email..." |

**Rationale:** Single-line fields HTML `<input type="text">` behavior. Enter submits form ([React
Native TextInput](https://reactnative.dev/docs/textinput) blurOnSubmit). Arrow up/down move to
start/end of text, no line navigation.

### Rich Text Editors (Multi-Line)

| Feature | Requirement | Differs From Code Editor | Notes |
|---------|-------------|--------------------------|-------|
| **Styled runs** | Preserve formatting on edit | Code: no formatting | VGlyph existing feature |
| **Format toolbar** | Bold/italic/color buttons | Code: no toolbar | v-gui responsibility |
| **Paragraph breaks** | Enter creates new paragraph | Code: new line | Semantic structure |
| **Paste formatting** | Keep or strip formatting | Code: strip formatting | User choice (Paste vs Paste Plain) |
| **Mixed fonts/sizes** | Font changes mid-text | Code: monospace only | VGlyph supports via runs |

**Rationale:** Rich text needs styled runs - VGlyph already supports (PROJECT.md). Editing must not
break run boundaries when inserting plain text. Format changes create new runs. Paste can preserve
rich text from clipboard or strip to plain.

### Code Editors (Multi-Line)

| Feature | Requirement | Differs From Rich Text | Notes |
|---------|-------------|------------------------|-------|
| **Line numbers** | Gutter with line numbers | Rich text: no gutter | CodeMirror gutter implementation |
| **Monospace font** | Fixed-width characters | Rich text: proportional | Alignment critical |
| **Tab key** | Insert tab or spaces | Rich text: focus next | Indent code, don't change focus |
| **Syntax coloring** | Colored keywords via runs | Rich text: user formatting | App applies colors to runs |
| **Auto-indent** | Match previous line indentation | Rich text: no indent | Language-aware (future) |

**Rationale:** Code editors need monospace for alignment. Line numbers essential ([CodeMirror
gutter](https://github.com/codemirror/gutter)). Tab inserts indentation, doesn't change focus
(unlike forms). Syntax highlighting uses VGlyph styled runs - app passes colored runs.

## VGlyph v1.3 MVP Recommendation

For v1.3 milestone, focus on **table stakes only** - defer differentiators to post-v1.3.

### Include in v1.3 (Table Stakes)

**Cursor:**
- Cursor positioning (click to position)
- Cursor → rect API
- Arrow key movement (char/word/line)
- Home/End keys
- Ctrl+Arrow word boundaries
- Vertical column memory

**Selection:**
- Click+drag selection
- Shift+arrow selection
- Double-click → word
- Triple-click → line
- Shift+Home/End
- Ctrl+A/Cmd+A select all
- Selection → rects API

**Mutation:**
- Insert character at cursor
- Backspace/Delete
- Cut/Copy/Paste
- Undo/Redo (50 action limit)

**IME:**
- NSTextInputClient implementation
- Composition window
- Candidate selection
- Dead key support

**v-gui Integration:**
- TextField widget (single-line)
- TextArea widget (multi-line)
- Demo with working editor

### Defer to post-v1.3

**Enhanced selection:**
- Rectangular selection (Alt+drag)
- Multiple cursors
- Expand selection
- Select occurrences

**Advanced mutation:**
- Drag and drop text
- Duplicate line
- Move line up/down
- Auto-indent (language-specific)

**Rich text specific:**
- Format selection (bold/italic)
- Format painter
- Style preservation on paste

**Code editor specific:**
- Line numbers gutter → **WAIT:** Actually v1.3 scope if code editor use case
- Bracket matching
- Auto-close brackets
- Comment toggle
- Code folding

**Search:**
- Find/replace (Ctrl+F)
- Regex support

**Rationale:** v1.3 delivers complete basic editing - cursor, selection, mutation, IME. Users can
type, select, cut/paste, undo. That's functional editor. Advanced features (multi-cursor,
drag-drop, search) add complexity - defer until basic editing proven solid.

**Line numbers decision:** PROJECT.md lists three use cases including "code editors with line
numbers." If line numbers are v1.3 scope, include basic gutter. If defer, just render text
content. Needs clarification.

## Complexity Assessment

| Feature Category | Complexity | LOC Estimate | Risk | Notes |
|------------------|------------|--------------|------|-------|
| Cursor system | Low | 200-300 | Low | State + geometry APIs |
| Selection system | Medium | 400-500 | Medium | Word boundaries tricky |
| Mutation basic | Low | 300-400 | Low | Insert/delete straightforward |
| Undo/redo | High | 500-700 | Medium | Command pattern, testing complex |
| Clipboard | Medium | 200-300 | Medium | System API, platform-specific |
| IME (macOS) | High | 600-800 | High | NSTextInputClient protocol complex |
| v-gui integration | Medium | 400-600 | Medium | Event routing, focus management |

**Total estimate:** 2,600-3,600 LOC for full v1.3 table stakes.

**Risk areas:**
- **IME:** NSTextInputClient protocol has many methods, composition state management complex,
  dead keys edge cases. Highest risk.
- **Undo/redo:** Command pattern requires all operations reversible, testing combinatorial
  explosion. Medium-high risk.
- **Word boundaries:** Unicode UAX#29 word segmentation rules complex, multiple languages.
  Medium risk.
- **Selection rendering:** Multi-line selections span multiple rects, bi-directional text
  complicates geometry. Medium risk.

## Validation Strategy

| Feature | How to Validate | Success Criteria |
|---------|----------------|------------------|
| **Cursor** | Click text, arrow keys | Cursor appears at correct position, moves correctly |
| **Selection** | Click+drag, double/triple-click | Highlighted region matches expected range |
| **Insert** | Type characters | Text appears at cursor, pushes existing text right |
| **Delete** | Backspace/Delete | Correct character removed, text shifts left |
| **Undo/Redo** | Edit sequence, undo all, redo all | Returns to initial state, forward to final state |
| **Clipboard** | Copy, paste across apps | Text transfers correctly with formatting |
| **IME** | Type Japanese/Chinese | Composition window appears, candidates selectable, commit works |
| **Single-line** | Press Enter in TextField | Form submits, no newline inserted |
| **Multi-line** | Press Enter in TextArea | Newline inserted, cursor moves down |

**Manual testing required for IME** - no good automated test for composition behavior. Need native
speakers to validate Chinese/Japanese/Korean input.

## Open Questions

- **Line numbers in v1.3?** PROJECT.md mentions "code editors (line numbers)" as use case.
  Include gutter in v1.3 or defer? Adds complexity but may be expectation.
- **Undo granularity?** Character-level (every keystroke) or word-level (undo whole word)?
  Character-level more intuitive but fills undo stack faster.
- **Selection color?** Use platform theme (NSColor.selectedTextBackgroundColor) or custom?
  Platform theme ensures accessibility contrast.
- **IME underline style?** Solid, dotted, thick? macOS standard is thick underline. Follow
  platform convention.
- **Clipboard format?** Plain text only or support RTF/HTML? Plain text MVP, rich text future?
- **Tab key behavior?** Insert tab character or spaces? Configurable? Tab width 4 or 8?
- **Scroll on cursor movement?** When cursor moves off-screen, scroll into view? Required for
  usability but VGlyph doesn't handle scrolling - v-gui responsibility?

## Confidence Assessment

| Topic | Confidence | Reason |
|-------|------------|--------|
| Cursor/selection behaviors | HIGH | Universal standards, well-documented |
| Keyboard shortcuts | HIGH | Platform conventions stable (Ctrl+C, Ctrl+V, etc.) |
| IME requirements | MEDIUM | NSTextInputClient documented but complex implementation |
| Undo/redo patterns | HIGH | Command pattern well-established |
| Word boundaries | MEDIUM | Unicode UAX#29 standard but complex rules |
| Use case differences | HIGH | HTML input vs textarea, documented behaviors |
| macOS platform integration | MEDIUM | NSTextInputClient exists, implementation details less clear |

**Gaps:**
- Unicode word segmentation implementation details (UAX#29 rules)
- NSTextInputClient composition state machine (marked text lifecycle)
- Dead key sequences for non-Latin scripts (beyond basic accents)
- Bi-directional text selection geometry (RTL languages)

**Verification needed:**
- Does Pango provide word boundary API or need ICU BreakIterator?
- Does v-gui have clipboard API or need platform-specific implementation?
- Does V language have Unicode string indexing issues (UTF-8 bytes vs grapheme clusters)?

## Sources

**Text Editing Behaviors:**
- [Cursor (user interface) - Wikipedia](https://en.wikipedia.org/wiki/Cursor_(user_interface))
- [Text Editor Cursor Behavior (emacs, vi, Notepad++)](http://xahlee.info/emacs/emacs/text_editor_cursor_behavior.html)
- [Microsoft Word text selection shortcuts](https://www.avantixlearning.ca/microsoft-word/check-out-these-timesaving-microsoft-word-selection-shortcuts-to-quickly-select-text/)
- [Triple-click - Wikipedia](https://en.wikipedia.org/wiki/Triple-click)

**Cursor Visual Standards:**
- [Cursor Blink Rate - Microsoft Learn](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/dnacc/flashing-user-interface-and-the-getcaretblinktime-function)
- [Change Text Cursor Blink Rate in Windows](https://www.tenforums.com/tutorials/95372-change-text-cursor-blink-rate-windows.html)

**IME and Composition:**
- [NSTextInputClient - Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nstextinputclient)
- [GitHub - jessegrosjean/NSTextInputClient](https://github.com/jessegrosjean/NSTextInputClient)
- [Text Editing - Apple Developer Archive](https://developer.apple.com/library/archive/documentation/TextFonts/Conceptual/CocoaTextArchitecture/TextEditing/TextEditing.html)
- [Dead key - Wikipedia](https://en.wikipedia.org/wiki/Dead_key)
- [VS Code Issue #288972 - Dead keys broken in terminal](https://github.com/microsoft/vscode/issues/288972)

**Clipboard:**
- [How to copy text - web.dev](https://web.dev/patterns/clipboard/copy-text)
- [Clipboard Module - Quill Rich Text Editor](https://quilljs.com/docs/modules/clipboard)

**Undo/Redo:**
- [Undo/redo implementations in text editors](https://www.mattduck.com/undo-redo-text-editors)
- [The Command Pattern: Undo/Redo](https://codezup.com/the-power-of-command-pattern-undo-redo-functionality/)
- [Design Thoughts: Undo Redo - super_editor Wiki](https://github.com/superlistapp/super_editor/wiki/Design-Thoughts:-Undo-Redo)

**Word Boundaries:**
- [Text boundaries - Microsoft Learn](https://learn.microsoft.com/en-us/globalization/fonts-layout/text-boundaries)
- [Boundary Analysis - ICU Documentation](https://unicode-org.github.io/icu/userguide/boundaryanalysis/)
- [Text Boundary Analysis in Java](https://icu-project.org/docs/papers/text_boundary_analysis_in_java/)

**Single-Line vs Multi-Line:**
- [ARIA: aria-multiline attribute - MDN](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-multiline)
- [TextInput - React Native](https://reactnative.dev/docs/textinput)

**Rich Text Editing:**
- [Compose Rich Editor - Getting Started](https://mohamedrejeb.github.io/compose-rich-editor/getting_started/)
- [CKEditor 5 Documentation - Drag and drop](https://ckeditor.com/docs/ckeditor5/latest/features/drag-drop.html)

**Code Editor Features:**
- [CodeMirror gutter](https://github.com/codemirror/gutter)
- [CodeMirror Gutter Example](https://codemirror.net/examples/gutter/)
- [IntelliJ IDEA - Editor gutter](https://www.jetbrains.com/help/idea/editor-gutter.html)

**Find/Replace:**
- [Find and replace text - Visual Studio](https://learn.microsoft.com/en-us/visualstudio/ide/finding-and-replacing-text?view=visualstudio)
- [EmEditor Find and Replace](https://www.emeditor.com/text-editor-features/coding/find-replace/)

**Accessibility:**
- [CKEditor Accessibility Support](https://ckeditor.com/docs/ckeditor4/latest/guide/dev_a11y.html)
- [ARIA - Accessibility - MDN](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA)

---

*Research complete. Features categorized for v1.3 roadmap creation.*
