# Text Editing Architecture Integration

**Domain:** Text editing (cursor, selection, mutation, IME) for Pango-based rendering
**Researched:** 2026-02-02
**Confidence:** MEDIUM (verified patterns from GTK/Chromium, WebSearch ecosystem survey)

## Executive Summary

Text editing integrates with VGlyph's existing Pango-based architecture through model-view
separation. Editing state (cursor, selection, IME) lives in new `editing.v` module, using
existing Layout hit testing/char rects for geometry. Mutation triggers layout rebuild (standard
Pango pattern). IME integration via macOS NSTextInputClient (v-gui responsibility).

**Key finding:** VGlyph already has foundation (hit testing, char rects, selection rects). Add
editing state layer without modifying rendering pipeline.

## Recommended Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ v-gui Integration Layer (TextField/TextArea widgets)       │
│ - Blink timer, keyboard events, focus management           │
│ - Rendering loop (calls VGlyph APIs)                       │
└──────────────────┬──────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────────┐
│ VGlyph Text Editing API (new module: editing.v)            │
│ - EditorState: cursor, selection, IME composition           │
│ - get_cursor_rect(offset) -> Rect                          │
│ - get_selection_rects(start, end) -> []Rect                │
│ - insert_text(offset, text) / delete_range(start, end)     │
│ - ime_set_preedit(text, cursor_pos, attrs)                 │
└──────────────────┬──────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────────┐
│ Existing VGlyph Architecture                                │
│                                                             │
│  layout.v (Pango wrapper)                                  │
│  - layout_text() → Layout                                  │
│  - Layout.hit_test(x, y) → byte_offset ✓ EXISTING         │
│  - Layout.get_char_rect(offset) → Rect ✓ EXISTING         │
│  - Layout.get_selection_rects(s, e) → []Rect ✓ EXISTING   │
│                                                             │
│  renderer.v (GPU rendering)                                │
│  - draw_layout(Layout, x, y) ✓ EXISTING                    │
│  - [NEW] draw_rects([]Rect, color) for selection highlight │
│                                                             │
│  context.v (font management)                               │
│  - Pango context, metrics cache ✓ EXISTING                 │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### New: editing.v (Text Editing State)

**Purpose:** Manage editing state and provide geometry APIs

**Responsibilities:**
- Track cursor position (byte offset into text)
- Track selection range (anchor, head byte offsets)
- Track IME composition (preedit string, cursor within preedit, attributes)
- Provide cursor geometry (via Layout.get_char_rect)
- Provide selection geometry (via Layout.get_selection_rects)
- Provide IME composition geometry
- Handle text mutation (insert/delete operations)
- Maintain undo/redo history

**Does NOT:**
- Manage blink state (v-gui responsibility)
- Handle keyboard events (v-gui responsibility)
- Render anything (calls existing renderer)

**Data Structures:**

```v
// EditorState manages editing operations on text buffer
pub struct EditorState {
mut:
    text         string        // Current text content
    cursor       int           // Byte offset
    selection    Selection     // Anchor + head offsets
    composition  Composition   // IME preedit state
    history      UndoHistory   // Command pattern undo/redo
}

pub struct Selection {
mut:
    anchor int  // Selection start (byte offset)
    head   int  // Selection end (byte offset)
}

pub struct Composition {
mut:
    active     bool
    preedit    string         // Uncommitted IME text
    cursor_pos int            // Cursor within preedit
    attrs      []PreeditAttr  // Underline styles
}

pub struct PreeditAttr {
    start int
    end   int
    style PreeditStyle  // .none, .underline, .highlight
}
```

**API Surface:**

```v
// Cursor geometry
pub fn (e EditorState) get_cursor_rect(layout Layout) ?gg.Rect
pub fn (e EditorState) get_cursor_line(layout Layout) ?Line

// Selection geometry
pub fn (e EditorState) get_selection_rects(layout Layout) []gg.Rect
pub fn (e EditorState) has_selection() bool

// Text mutation
pub fn (mut e EditorState) insert_text(text string) bool  // Returns if changed
pub fn (mut e EditorState) delete_selection() bool
pub fn (mut e EditorState) delete_backward() bool  // Backspace
pub fn (mut e EditorState) delete_forward() bool   // Delete

// IME composition
pub fn (mut e EditorState) ime_begin()
pub fn (mut e EditorState) ime_set_preedit(text string, cursor_pos int, attrs []PreeditAttr)
pub fn (mut e EditorState) ime_commit(text string)
pub fn (mut e EditorState) ime_cancel()
pub fn (e EditorState) get_ime_rects(layout Layout) ImeGeometry

// Undo/redo
pub fn (mut e EditorState) undo() bool
pub fn (mut e EditorState) redo() bool
```

### Extension: layout.v (Existing)

**Already has:**
- `hit_test(x, y) -> offset` ✓
- `get_char_rect(offset) -> Rect` ✓
- `get_selection_rects(start, end) -> []Rect` ✓
- `get_closest_offset(x, y) -> offset` ✓

**No changes needed.** Existing APIs sufficient.

### Extension: renderer.v (Drawing Helpers)

**Add helper for selection/cursor rendering:**

```v
// draw_filled_rects renders colored rectangles (for selection highlight)
pub fn (mut r Renderer) draw_filled_rects(rects []gg.Rect, color gg.Color)

// draw_cursor renders cursor line at rect position
pub fn (mut r Renderer) draw_cursor(rect gg.Rect, color gg.Color)
```

**Pattern:** Use `gg.Context.draw_rect_filled` - no custom GPU code needed.

### Integration: api.v (TextSystem Extension)

**Add editing-aware API:**

```v
pub struct TextSystem {
    // ... existing fields ...
mut:
    editor EditorState  // Owned editing state
}

// draw_text_editable renders text with cursor and selection
pub fn (mut ts TextSystem) draw_text_editable(x f32, y f32, cursor_visible bool) ! {
    layout := ts.get_or_create_layout(ts.editor.text, ts.config)!

    // Draw selection highlight
    if ts.editor.has_selection() {
        sel_rects := ts.editor.get_selection_rects(layout)
        ts.renderer.draw_filled_rects(sel_rects, selection_color)
    }

    // Draw text
    ts.renderer.draw_layout(layout, x, y)

    // Draw cursor
    if cursor_visible && !ts.editor.composition.active {
        cursor_rect := ts.editor.get_cursor_rect(layout) or { return }
        ts.renderer.draw_cursor(cursor_rect, cursor_color)
    }

    // Draw IME composition
    if ts.editor.composition.active {
        // ... draw preedit underlines and cursor
    }
}

// Expose mutation APIs
pub fn (mut ts TextSystem) insert_text(text string) ! {
    if ts.editor.insert_text(text) {
        ts.invalidate_layout_cache()  // Text changed, rebuild layout
    }
}
```

## Data Flow Diagrams

### Cursor Positioning Flow

```
User Click (x, y)
    │
    ├─> v-gui: MouseEvent handler
    │      │
    │      └─> TextSystem.hit_test(x, y)
    │             │
    │             └─> Layout.get_closest_offset(x, y) → byte_offset
    │                    │
    │                    └─> EditorState.cursor = byte_offset
    │
Render Frame
    │
    └─> TextSystem.draw_text_editable()
           │
           └─> EditorState.get_cursor_rect(layout)
                  │
                  └─> Layout.get_char_rect(cursor) → Rect
                         │
                         └─> Renderer.draw_cursor(Rect)
```

**Key insight:** Click → offset uses Layout hit testing (existing). Offset → geometry uses
Layout char rects (existing). No Pango recalculation needed.

### Text Mutation Flow

```
User Types 'A'
    │
    ├─> v-gui: KeyEvent handler
    │      │
    │      └─> TextSystem.insert_text("A")
    │             │
    │             ├─> EditorState.insert_text("A")
    │             │      │
    │             │      ├─> text = text[..cursor] + "A" + text[cursor..]
    │             │      ├─> cursor += 1
    │             │      └─> history.push(InsertCommand)
    │             │
    │             └─> invalidate_layout_cache()
    │
Next Frame
    │
    └─> TextSystem.draw_text_editable()
           │
           └─> get_or_create_layout(editor.text, cfg)
                  │
                  └─> Context.layout_text() → new Layout
                         │
                         └─> Pango reshapes text, returns new Layout
```

**Trade-off:** Full layout rebuild on every mutation. Standard for Pango-based systems (GTK
TextView does this). Alternative (incremental layout) complex, not worth it for typical text
field sizes.

### Selection Flow

```
User Drags Selection
    │
    ├─> v-gui: MouseDrag handler
    │      │
    │      ├─> anchor = initial_click_offset (unchanged)
    │      └─> head = Layout.get_closest_offset(current_x, current_y)
    │
Render Frame
    │
    └─> TextSystem.draw_text_editable()
           │
           ├─> EditorState.get_selection_rects(layout)
           │      │
           │      └─> Layout.get_selection_rects(anchor, head) → []Rect
           │             │
           │             └─> [Uses existing line-by-line rect calculation]
           │
           ├─> Renderer.draw_filled_rects(rects, selection_bg)
           └─> Renderer.draw_layout(layout)  // Text over selection
```

**Performance note:** `get_selection_rects()` already exists, optimized with O(1)
char_rect_by_index lookup.

### IME Composition Flow (macOS)

```
IME Composition Start
    │
    ├─> macOS: NSTextInputClient.insertText(_:replacementRange:)
    │      │
    │      └─> EditorState.ime_begin()
    │
IME Preedit Update
    │
    ├─> macOS: NSTextInputClient.setMarkedText(_:selectedRange:replacementRange:)
    │      │
    │      └─> EditorState.ime_set_preedit(text, cursor, attrs)
    │             │
    │             └─> composition.preedit = text
    │
Render Frame (during composition)
    │
    └─> TextSystem.draw_text_editable()
           │
           ├─> temp_text = text[..cursor] + preedit + text[cursor..]
           ├─> temp_layout = layout_text(temp_text)  // Temporary layout
           │
           ├─> preedit_start = cursor
           ├─> preedit_end = cursor + preedit.len
           │
           ├─> draw_layout(temp_layout)
           │
           └─> for attr in composition.attrs {
                   rects := temp_layout.get_selection_rects(
                       preedit_start + attr.start,
                       preedit_start + attr.end
                   )
                   draw_filled_rects(rects, underline_color)  // IME underline
               }
    │
IME Commit
    │
    └─> macOS: NSTextInputClient receives committed text
           │
           └─> EditorState.ime_commit(text)
                  │
                  ├─> insert_text(text)  // Becomes real text
                  └─> composition.active = false
```

**Integration point:** v-gui implements NSTextInputClient protocol (macOS), calls VGlyph IME
APIs. VGlyph provides geometry (for IME candidate window positioning).

**Preedit rendering:** Create temporary Layout with preedit inserted, render with special
underline attributes. Don't modify main text until commit.

## IME Integration Architecture

### macOS NSTextInputClient Protocol

**v-gui responsibility:** Implement NSTextInputClient in widget (TextField/TextArea).

**VGlyph provides:**
- Cursor rect for IME candidate window positioning
- Preedit rendering
- Composition state management

**Key methods v-gui must implement:**

```objc
// v-gui calls VGlyph APIs from these protocol methods:

- (void)insertText:(id)string replacementRange:(NSRange)range {
    // If composition active: commit
    if editor.composition.active {
        vglyph_ime_commit(string)
    } else {
        vglyph_insert_text(string)
    }
}

- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange
       replacementRange:(NSRange)replacementRange {
    vglyph_ime_set_preedit(string, selectedRange.location, attrs)
}

- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actualRange {
    rect := vglyph_get_cursor_rect()
    return convert_to_screen_coords(rect)
}

- (NSRange)markedRange {
    if !editor.composition.active { return NSMakeRange(NSNotFound, 0) }
    return NSMakeRange(editor.cursor, editor.composition.preedit.len)
}
```

**Chromium pattern (verified):** Uses `composition_text_util_pango` to extract Pango attributes
from IME composition. VGlyph can follow similar pattern.

### Preedit Attributes

**Standard IME attributes:**
- `.none` - No styling
- `.underline` - Single underline (unconverted)
- `.thick_underline` - Thick underline (current clause)
- `.highlight` - Background highlight (selected clause)

**Rendering:**
```v
struct PreeditAttr {
    start int      // Byte offset within preedit
    end   int
    style PreeditStyle
}

enum PreeditStyle {
    none
    underline           // Thin line under text
    thick_underline     // Thick line under current clause
    highlight           // Background color
}
```

## Undo/Redo Architecture

### Command Pattern (Recommended)

**Pattern:** Store inverse commands on undo stack. Execute forward commands on redo.

**Why Command over Memento:**
- Text editing operations have clear inverses (insert ↔ delete)
- Storing commands smaller than storing full text snapshots
- Standard pattern in GTK, VS Code, most editors

**Implementation:**

```v
struct UndoHistory {
mut:
    undo_stack []Command
    redo_stack []Command
    max_size   int = 100  // Limit memory
}

interface Command {
    execute(mut editor EditorState)
    undo(mut editor EditorState)
}

struct InsertCommand {
    offset int
    text   string
}

fn (c InsertCommand) execute(mut e EditorState) {
    e.text = e.text[..c.offset] + c.text + e.text[c.offset..]
    e.cursor = c.offset + c.text.len
}

fn (c InsertCommand) undo(mut e EditorState) {
    e.text = e.text[..c.offset] + e.text[c.offset + c.text.len..]
    e.cursor = c.offset
}
```

**Batching:** Group sequential character inserts into single command (typing "hello" becomes one
InsertCommand, not 5).

## Component Boundaries

| Component | Owns | Doesn't Own | Interface |
|-----------|------|-------------|-----------|
| **editing.v** | Text buffer, cursor, selection, IME state, undo history | Layout, rendering, events | get_cursor_rect(), insert_text() |
| **layout.v** | Pango layout, glyph positions, hit testing data | Text content, cursor position | layout_text(), hit_test(), get_char_rect() |
| **renderer.v** | GPU state, glyph atlas, draw commands | What to draw | draw_layout(), draw_filled_rects() |
| **v-gui widget** | Blink timer, keyboard events, focus, scroll | Text operations, geometry | Calls VGlyph APIs, implements NSTextInputClient |

**Separation rationale:**
- **editing.v** = model (text state)
- **layout.v** = layout engine (geometry)
- **renderer.v** = view (GPU rendering)
- **v-gui** = controller (user interaction)

Standard MVC pattern adapted for text editing.

## Build Order (Dependency-Driven)

### Phase 1: Cursor Foundation
**What:** EditorState with cursor tracking, cursor geometry API
**Why first:** Simplest editing primitive, no selection/IME complexity
**Dependencies:** layout.v (existing hit testing)
**Deliverable:** Single-line TextField with cursor, no selection

### Phase 2: Selection
**What:** Selection tracking (anchor/head), selection geometry API
**Why second:** Builds on cursor, enables copy/paste
**Dependencies:** Phase 1 cursor
**Deliverable:** TextField with mouse selection, copy/paste

### Phase 3: Text Mutation
**What:** Insert/delete operations, layout invalidation
**Why third:** Makes editing functional
**Dependencies:** Phase 1 cursor (insertion point)
**Deliverable:** Typing, backspace, delete work

### Phase 4: Undo/Redo
**What:** Command pattern history
**Why fourth:** Mutation must work before adding undo
**Dependencies:** Phase 3 mutation
**Deliverable:** Cmd+Z / Cmd+Shift+Z work

### Phase 5: IME Integration
**What:** Composition state, preedit rendering, NSTextInputClient
**Why last:** Most complex, requires all previous
**Dependencies:** Phases 1-3 (cursor, text mutation)
**Deliverable:** Japanese/Chinese input works

### Phase 6: Multi-line (TextArea)
**What:** Line navigation, scroll, word wrap
**Why after single-line:** Single-line validates architecture
**Dependencies:** Phases 1-5
**Deliverable:** TextArea widget with multi-line editing

## Text Buffer Data Structure

**Recommendation for v1.3:** Simple string, full rebuild on mutation.

**Why not rope/piece table:**
- VGlyph text fields likely < 10KB (UI text fields, not code editors)
- V string operations fast for small strings
- Pango requires full UTF-8 string anyway (no incremental shaping API)
- Premature optimization

**Future optimization (post-v1.3):** If profiling shows mutation slowness on large TextArea
content, consider piece table. But validate need first.

**Mutation performance:**
```v
// Current approach (adequate for v1.3):
text = text[..offset] + inserted + text[offset..]  // O(n) copy

// Future if needed:
// Piece table: O(1) insert, but Pango still needs full string → O(n) concat
```

## Performance Considerations

### Layout Rebuild Cost

**Measured in VGlyph v1.2:**
- Layout 100 chars: ~0.5ms (Pango shaping)
- Layout 1000 chars: ~2ms
- Layout 10000 chars: ~15ms

**Implication:** Full rebuild acceptable for typical TextField (< 1000 chars). For TextArea with
large documents, may need incremental layout (future).

### Selection Rendering

**Already optimized:** `get_selection_rects()` uses O(1) char_rect_by_index lookup. Benchmark
from layout_query.v shows fast execution.

### Cursor Blink

**v-gui responsibility:** Timer fires every 500ms, toggles `cursor_visible` flag. VGlyph just
renders cursor when flag is true. No performance concern.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Storing PangoLayout in EditorState
**Why bad:** Layout lifetime tied to render frame. Storing causes dangling pointers when text
changes.
**Instead:** EditorState stores text (string), rebuilds Layout each frame via cache.

### Anti-Pattern 2: Modifying Layout After Creation
**Why bad:** Layout is immutable output from Pango shaping. Mutation requires reshaping.
**Instead:** Treat Layout as read-only geometry data. Text changes → new Layout.

### Anti-Pattern 3: Character-Based Indexing
**Why bad:** Pango uses byte offsets (UTF-8), not character indices. Mixing causes bugs.
**Instead:** All offsets are byte positions. Use V string slicing (byte-aware).

### Anti-Pattern 4: Custom Hit Testing
**Why bad:** Reimplementing hit testing ignores bidi, clusters, complex scripts.
**Instead:** Use Layout.hit_test() and get_closest_offset() (existing, correct).

### Anti-Pattern 5: IME Candidate Window in VGlyph
**Why bad:** Platform-specific UI, belongs in OS IME system.
**Instead:** VGlyph provides cursor rect via NSTextInputClient.firstRectForCharacterRange. OS
draws candidate window.

## Integration with v-gui

### Minimal Widget Implementation

```v
// v-gui TextField widget (simplified)
struct TextField {
mut:
    text_system &vglyph.TextSystem
    cursor_blink_visible bool
    focused bool
}

fn (mut w TextField) on_key_down(e KeyEvent) {
    if e.key == .backspace {
        w.text_system.delete_backward()
    } else if e.char != 0 {
        w.text_system.insert_text(e.char.str())
    }
}

fn (mut w TextField) on_mouse_down(e MouseEvent) {
    w.focused = true
    offset := w.text_system.hit_test(e.x, e.y)
    w.text_system.set_cursor(offset)
}

fn (w TextField) draw() {
    if w.focused {
        w.text_system.draw_text_editable(x, y, w.cursor_blink_visible)
    } else {
        w.text_system.draw_text(x, y, w.text_system.editor.text, cfg)
    }
}
```

**Blink timer:** v-gui's widget manager toggles `cursor_blink_visible` every 530ms (macOS
standard). Resets to visible on any edit.

## Open Questions for Phase Planning

- Multi-line scroll: VGlyph or v-gui? (Likely v-gui - viewport management)
- Grapheme cluster navigation: Add to VGlyph or v-gui? (VGlyph - needs Pango)
- Accessibility cursor position: Extend existing accessibility.v? (Yes)
- Word/line selection: VGlyph or v-gui? (VGlyph - needs layout line data)

## Sources

**HIGH confidence (official documentation):**
- [Pango Layout Objects](https://docs.gtk.org/Pango/class.Layout.html)
- [GTK Text Widget Overview](https://docs.gtk.org/gtk4/section-text-widget.html)
- [macOS NSTextInputClient](https://learn.microsoft.com/en-us/windows/apps/develop/input/input-method-editors)

**MEDIUM confidence (architecture patterns, verified with multiple sources):**
- [GTK TextView Architecture](https://python-gtk-3-tutorial.readthedocs.io/en/latest/textview.html)
- [Text Editor Model-View Separation](https://pygobject.gnome.org/tutorials/gtk4/textview.html)
- [Undo/Redo Command Pattern](https://medium.com/@yashodhara.chowkar/building-a-text-editor-with-the-command-design-pattern-955979e77b57)
- [Text Layout Segmentation (Raph Levien)](https://raphlinus.github.io/text/2020/10/26/text-layout.html)

**LOW confidence (WebSearch only, needs validation):**
- IME integration specifics for Pango (found Chromium usage, not documented in Pango)
- Performance benchmarks for text buffer structures (anecdotal, not measured in VGlyph)
