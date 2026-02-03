# Phase 16: API & Demo - Research

**Researched:** 2026-02-03
**Domain:** API documentation and demo application for text editing
**Confidence:** HIGH

## Summary

Phase 16 documents and demonstrates editing APIs built in Phases 11-15. VGlyph follows
established patterns: methods-on-Layout for cursor/selection queries, pure mutation functions
returning MutationResult, UndoManager with operation coalescing. Demo exists (editor_demo.v) -
enhance to show status bar with editing state metrics.

Documentation style: inline docstrings (V standard) + separate markdown guide. Guide structure:
quick examples, API reference by category, integration patterns. IME section covers working macOS
bridge, appendix notes future CJK multi-clause support.

**Primary recommendation:** Audit existing docstrings for completeness, write guide with minimal
but clear examples, enhance demo with status bar showing line:col, selection length, undo depth.

## Standard Stack

VGlyph editing layer built on existing dependencies - no new libraries.

### Core (Existing)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Pango | 1.0 | Text layout, grapheme navigation | Industry standard for complex text |
| V stdlib | latest | String manipulation, builder | Native V strings for mutations |
| gg | builtin | Graphics primitives | V's graphics layer |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| v fmt | Code formatting | Before commit |
| v doc | Generate API docs | CI/CD pipeline |
| v check-md | Markdown line length | Before commit (99 char) |

### Documentation Tools (V Language)
| Component | Usage |
|-----------|-------|
| Inline docstrings | `// function_name does X` format above pub fns |
| v doc | `v doc -o docs/api.html vglyph` generates HTML from docstrings |
| Markdown | Separate guides in docs/ directory |

**Installation:**
```bash
# Already satisfied by v1.2 dependencies
pkg-config pango pangoft2
```

## Architecture Patterns

### Existing Pattern: Methods-on-Layout
```v
// Cursor positioning (Phase 11)
pub fn (l Layout) get_cursor_pos(byte_index int) ?CursorPosition
pub fn (l Layout) move_cursor_left(byte_index int) int
pub fn (l Layout) move_cursor_word_left(byte_index int) int

// Selection (Phase 12)
pub fn (l Layout) get_selection_rects(start int, end int) []gg.Rect
pub fn (l Layout) get_word_at_index(byte_index int) (int, int)
```

**Why this pattern:** Stateless layout queries keep Layout immutable after creation.

### Existing Pattern: Pure Mutation Functions
```v
// Mutation (Phase 13)
pub fn insert_text(text string, cursor int, insert string) MutationResult
pub fn delete_backward(text string, layout Layout, cursor int) MutationResult

pub struct MutationResult {
    new_text     string  // Result text
    cursor_pos   int     // New cursor position
    deleted_text string  // For undo
    range_start  int     // For change tracking
    range_end    int
}
```

**Why this pattern:** Pure functions - caller applies changes, enables undo tracking.

### Existing Pattern: UndoManager with Coalescing
```v
// Undo (Phase 14)
pub struct UndoManager {
mut:
    undo_stack []UndoOperation
    redo_stack []UndoOperation
    coalescable_op ?UndoOperation  // Pending merge
}

// Usage
state.undo_mgr.record_mutation(result, inserted_text, cursor_before, anchor_before)
state.undo_mgr.undo(text, cursor, anchor) ?(string, int, int)
```

**Why this pattern:** Command pattern with coalescing (1s timeout) matches user expectations.

### IME Pattern: Callback Registration
```v
// IME (Phase 15)
pub struct CompositionState {
mut:
    phase        CompositionPhase  // none | composing
    preedit_text string
    cursor_offset int
}

// C bridge registration
vglyph.ime_register_callbacks(ime_marked_text, ime_insert_text, ime_unmark_text,
    ime_bounds, state_ptr)
```

**Why this pattern:** Native IME bridge requires C callbacks, state passed via user_data.

### Demo Architecture: Single State Struct
```v
@[heap]
struct EditorState {
mut:
    gg_ctx   &gg.Context
    ts       &vglyph.TextSystem
    text     string
    layout   vglyph.Layout
    cursor_idx   int
    anchor_idx   int
    has_selection bool
    undo_mgr     vglyph.UndoManager
    composition  vglyph.CompositionState
    dead_key     vglyph.DeadKeyState
    // NEW: status tracking
    current_line int
    current_col  int
}
```

**Why this pattern:** Heap-allocated state passed through gg user_data, survives event/frame
callbacks.

### Documentation Structure (Recommended)
```
docs/
├── API.md              # Existing rendering API
├── EDITING.md          # NEW: Editing API guide
└── IME-APPENDIX.md     # NEW: IME details + future plans

EDITING.md structure:
1. Quick Start (basic editing example)
2. Cursor API (positioning, navigation)
3. Selection API (ranges, rects, utilities)
4. Mutation API (insert, delete, MutationResult)
5. Undo API (manager, coalescing, navigation breaks)
6. IME API (composition, callbacks, platform notes)
7. Integration Patterns (v-gui notes)
```

## Don't Hand-Roll

Problems with existing solutions in VGlyph:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Grapheme navigation | Byte-level movement | Layout.move_cursor_* | Pango handles clusters |
| Unicode normalization | Manual combining | Pango/HarfBuzz | Complex rules |
| Word boundaries | Regex/whitespace | Layout.get_word_at_index | Locale-aware |
| Bidi cursor movement | Linear arithmetic | Layout cursor methods | Visual order complex |
| Selection rects | Manual line wrapping | Layout.get_selection_rects | Multi-line correct |
| Undo coalescing | Time-based only | UndoManager | Adjacency + timeout |

**Key insight:** Pango provides correct Unicode behavior. Layout methods already expose it. Don't
bypass with byte arithmetic.

## Common Pitfalls

### Pitfall 1: Byte Index vs Grapheme Boundary
**What goes wrong:** Direct string slicing `text[cursor..]` mid-grapheme corrupts emoji/combiners.
**Why it happens:** V strings are UTF-8 byte arrays, cursor is byte offset.
**How to avoid:** ALWAYS use Layout.move_cursor_* to find boundaries before mutation.
**Warning signs:** Emoji split in half, combining accent appears separately.

### Pitfall 2: Cursor Position After Layout Rebuild
**What goes wrong:** Cursor jumps after text mutation.
**Why it happens:** MutationResult.cursor_pos must be applied - old cursor invalid.
**How to avoid:** Use result.cursor_pos, clamp to [0, new_text.len].
**Warning signs:** Cursor at wrong position after typing.

### Pitfall 3: Selection Anchor/Head Ordering
**What goes wrong:** Selection operations assume cursor > anchor.
**Why it happens:** Anchor is selection start, cursor can be before or after.
**How to avoid:** Normalize range: `start = min(cursor, anchor); end = max(cursor, anchor)`.
**Warning signs:** Selection delete removes wrong range.

### Pitfall 4: IME Composition Cursor Visibility
**What goes wrong:** Cursor hidden during composition.
**Why it happens:** Application disables cursor during preedit.
**How to avoid:** Keep cursor visible at composition.get_document_cursor_pos().
**Warning signs:** Can't see where text will insert during Japanese input.

### Pitfall 5: Undo Coalescing Navigation
**What goes wrong:** Undo reverts too much (entire typing session).
**Why it happens:** Navigation keys don't break coalescing.
**How to avoid:** Call undo_mgr.break_coalescing() on arrow keys, mouse clicks.
**Warning signs:** Ctrl+Z undoes 100 characters instead of last word.

### Pitfall 6: Docstring Mismatch with Implementation
**What goes wrong:** Documentation says function returns Option, code returns Result.
**Why it happens:** Code evolved, docstrings not updated.
**How to avoid:** Review signature match during audit: `?(T)` vs `!T` vs `T`.
**Warning signs:** Compiler allows both but semantics differ.

## Code Examples

Verified patterns from existing codebase:

### Basic Text Editing
```v
// Source: examples/editor_demo.v
mut state := &EditorState{
    text: 'Hello World'
    cursor_idx: 5
}

// Perform mutation
result := vglyph.insert_text(state.text, state.cursor_idx, ' ')
new_layout := state.ts.layout_text(result.new_text, state.cfg) or { return }

// Apply result atomically
state.text = result.new_text
state.layout = new_layout
state.cursor_idx = result.cursor_pos
```

### Cursor Rendering
```v
// Source: examples/editor_demo.v:798
if pos := state.layout.get_cursor_pos(state.cursor_idx) {
    state.gg_ctx.draw_rect_filled(offset_x + pos.x, offset_y + pos.y,
        2, pos.height, gg.red)
}
```

### Selection Highlight
```v
// Source: examples/editor_demo.v:757
if state.has_selection {
    start := min(state.cursor_idx, state.anchor_idx)
    end := max(state.cursor_idx, state.anchor_idx)
    rects := state.layout.get_selection_rects(start, end)
    for r in rects {
        state.gg_ctx.draw_rect_filled(offset_x + r.x, offset_y + r.y,
            r.width, r.height, gg.Color{50, 50, 200, 100})
    }
}
```

### Undo/Redo
```v
// Source: examples/editor_demo.v:282
if cmd_held && e.key_code == .z && !shift_held {
    // Undo
    if new_text, new_cursor, new_anchor := state.undo_mgr.undo(
        state.text, state.cursor_idx, state.anchor_idx) {
        state.text = new_text
        state.cursor_idx = new_cursor
        state.anchor_idx = new_anchor
        state.has_selection = (new_cursor != new_anchor)
        state.layout = state.ts.layout_text(state.text, state.cfg) or { return }
    }
}
```

### IME Callback Pattern
```v
// Source: examples/editor_demo.v:808
fn ime_marked_text(text &char, cursor_pos int, user_data voidptr) {
    mut state := unsafe { &EditorState(user_data) }
    if !state.composition.is_composing() {
        state.composition.start(state.cursor_idx)
    }
    preedit := unsafe { cstring_to_vstring(text) }
    state.composition.set_marked_text(preedit, cursor_pos)
}
```

### IME Composition Rendering
```v
// Source: examples/editor_demo.v:780
if state.composition.is_composing() {
    clause_rects := state.composition.get_clause_rects(state.layout)
    for cr in clause_rects {
        thickness := match cr.style {
            .selected { f32(2) }  // Thick underline for selected clause
            else { f32(1) }       // Thin underline
        }
        for r in cr.rects {
            underline_y := offset_y + r.y + r.height - 2
            state.gg_ctx.draw_rect_filled(offset_x + r.x, underline_y,
                r.width, thickness, gg.black)
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| String byte ops | Layout cursor methods | Phase 11 | Grapheme-correct |
| Manual undo stack | UndoManager coalescing | Phase 14 | User expectations |
| No IME | NSTextInputClient bridge | Phase 15 | CJK input works |

**Current as of v1.3:** All editing primitives implemented, macOS IME functional.

**Not yet implemented:**
- Multi-clause IME (Japanese conversion) - bridge supports it, demo shows single underline only
- Linux/Windows IME - macOS only currently
- TextArea widget in v-gui - VGlyph provides primitives

## Open Questions

1. **Error handling consistency**
   - What we know: Mix of `?T` (Option) and `!T` (Result) returns
   - What's unclear: Which pattern for new APIs? Audit needed.
   - Recommendation: Survey existing APIs, document convention, apply consistently

2. **Line/column calculation**
   - What we know: Layout has line data (l.lines array with start_index, length)
   - What's unclear: Public API for byte_index → (line, col) conversion
   - Recommendation: Check if Layout.lines sufficient or need helper function

3. **v-gui integration section**
   - What we know: VGlyph provides primitives, v-gui builds widgets
   - What's unclear: How detailed should integration notes be?
   - Recommendation: Brief section with state management pattern, point to v-gui docs

## Sources

### Primary (HIGH confidence)
- VGlyph codebase (Phases 11-15 implementation)
  - /Users/mike/Documents/github/vglyph/layout_query.v
  - /Users/mike/Documents/github/vglyph/layout_mutation.v
  - /Users/mike/Documents/github/vglyph/undo.v
  - /Users/mike/Documents/github/vglyph/composition.v
  - /Users/mike/Documents/github/vglyph/examples/editor_demo.v
- V language documentation conventions
  - `v help doc` - docstring extraction
  - Inline `//` comments standard

### Secondary (MEDIUM confidence)
- .planning/research/STACK.md - Architecture decisions from Phases 11-15
- .planning/research/ARCHITECTURE.md - Pattern documentation

### Tertiary (LOW confidence)
- Web search unavailable - no external verification performed

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - verified from codebase and existing docs
- Architecture: HIGH - patterns established in Phases 11-15, working code
- Pitfalls: MEDIUM - derived from code inspection, not from documented issues
- Code examples: HIGH - extracted from working editor_demo.v

**Research date:** 2026-02-03
**Valid until:** 60 days (editing APIs stable, demo patterns established)
