# Phase 13: Text Mutation - Research

**Researched:** 2026-02-02
**Domain:** Text insertion, deletion, and change events in grapheme-aware editing
**Confidence:** HIGH

## Summary

Text mutation builds on Phases 11-12 (cursor/selection) to enable text editing operations. The core
challenge is maintaining correct byte indices while operating on grapheme clusters, invalidating
layout caches, and providing change events for undo/redo integration. VGlyph owns layout, not the
text buffer - mutation modifies the app's string, then regenerates layout.

Key insight: VGlyph is a rendering library, not a text editor. The app owns the text string. VGlyph
provides grapheme-aware APIs for determining what to delete/where to insert, and the app performs
string mutations. After mutation, the app calls `layout_text` to regenerate layout. Layout cache
invalidation happens automatically via the cache key (text hash changes).

User decisions lock the following: insert mode only (no overwrite), full grapheme cluster support,
v-gui handles clipboard pasteboard, callback-based change events with batching for rapid mutations,
selection replacement on type. Claude's discretion covers: layout invalidation timing (recommend
immediate), callback signature, internal batching implementation.

**Primary recommendation:** Implement mutation primitives as pure functions returning modified
strings + adjustment info, let app handle actual string mutation and layout regeneration.

## Standard Stack

No external libraries needed - uses existing VGlyph/Pango APIs and V's `strings.Builder`.

### Core V APIs for String Mutation
| API | Source | Purpose | Status |
|-----|--------|---------|--------|
| `strings.new_builder(cap)` | strings module | Efficient string building | Stdlib |
| `builder.write_string(s)` | strings module | Append string to buffer | Stdlib |
| `builder.str()` | strings module | Extract final string | Stdlib |
| `string[start..end]` | builtin | Substring slicing | Stdlib |
| `string.runes()` | builtin | Get UTF-8 codepoints | Stdlib |

### Core VGlyph APIs (existing from Phases 11-12)
| API | Location | Purpose | Status |
|-----|----------|---------|--------|
| `Layout.log_attrs` | layout_types.v | Grapheme boundaries | Working |
| `Layout.log_attr_by_index` | layout_types.v | Byte index to attr | Working |
| `Layout.get_valid_cursor_positions()` | layout_query.v | All valid positions | Working |
| `Layout.move_cursor_left/right` | layout_query.v | Grapheme navigation | Working |
| `Layout.move_cursor_word_left/right` | layout_query.v | Word navigation | Working |
| `Layout.move_cursor_line_start/end` | layout_query.v | Line navigation | Working |
| `Layout.get_word_at_index` | layout_query.v | Word boundaries | Working |
| `TextSystem.layout_text` | api.v | Generate new layout | Working |
| `TextSystem.layout_text_cached` | api.v | Cached layout | Working |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| String slicing | strings.Builder | Builder better for multi-insert |
| Immediate layout regen | Deferred/batched | Immediate simpler, batched risks stale state |
| App owns text | VGlyph owns text | VGlyph as renderer, not editor - app ownership correct |

## Architecture Patterns

### Recommended Mutation Model

VGlyph provides query APIs, app performs mutations:

```v
// VGlyph provides: "what should I delete?"
// Example: get_delete_range(cursor, direction) -> (start, end)

// App performs: actual string manipulation
// text = text[..start] + text[end..]

// App updates: layout regeneration
// layout = ts.layout_text(text, cfg)
```

### Pattern 1: Mutation Result Struct
**What:** Return mutation info without modifying text directly
**When to use:** All mutation operations
**Example:**
```v
// Source: Standard text editor pattern

pub struct MutationResult {
pub:
    new_text     string   // Result of applying mutation
    cursor_pos   int      // New cursor position after mutation
    deleted_text string   // Text that was removed (for undo)
    range_start  int      // Start of affected range (for change event)
    range_end    int      // End of affected range (for change event)
}

// Delete backward one grapheme cluster
pub fn delete_backward(text string, layout Layout, cursor int) MutationResult {
    if cursor == 0 {
        return MutationResult{ new_text: text, cursor_pos: 0 }
    }

    // Find previous valid cursor position (grapheme boundary)
    prev_pos := layout.move_cursor_left(cursor)

    // Build new string
    mut sb := strings.new_builder(text.len)
    sb.write_string(text[..prev_pos])
    sb.write_string(text[cursor..])

    return MutationResult{
        new_text:     sb.str()
        cursor_pos:   prev_pos
        deleted_text: text[prev_pos..cursor]
        range_start:  prev_pos
        range_end:    cursor
    }
}
```

### Pattern 2: Insert at Cursor with Selection Replacement
**What:** Insert text, replacing selection if active
**When to use:** Character insertion, paste
**Example:**
```v
// Source: Standard text editor pattern

pub fn insert_text(text string, layout Layout, cursor int, anchor int, insert string) MutationResult {
    // Determine selection range (if any)
    has_selection := cursor != anchor
    sel_start := if cursor < anchor { cursor } else { anchor }
    sel_end := if cursor < anchor { anchor } else { cursor }

    // Build new string
    mut sb := strings.new_builder(text.len + insert.len)
    sb.write_string(text[..sel_start])
    sb.write_string(insert)
    sb.write_string(text[sel_end..])

    new_cursor := sel_start + insert.len

    return MutationResult{
        new_text:     sb.str()
        cursor_pos:   new_cursor
        deleted_text: if has_selection { text[sel_start..sel_end] } else { '' }
        range_start:  sel_start
        range_end:    sel_start + insert.len
    }
}
```

### Pattern 3: Word/Line Deletion
**What:** Delete to word/line boundary (Option+Backspace, Cmd+Backspace)
**When to use:** Modifier+Delete key combinations
**Example:**
```v
// Option+Backspace: delete to word boundary
pub fn delete_to_word_boundary(text string, layout Layout, cursor int) MutationResult {
    if cursor == 0 {
        return MutationResult{ new_text: text, cursor_pos: 0 }
    }

    // Get word start before cursor (per user decision: "to boundary not whole word")
    word_start := layout.move_cursor_word_left(cursor)

    mut sb := strings.new_builder(text.len)
    sb.write_string(text[..word_start])
    sb.write_string(text[cursor..])

    return MutationResult{
        new_text:     sb.str()
        cursor_pos:   word_start
        deleted_text: text[word_start..cursor]
        range_start:  word_start
        range_end:    cursor
    }
}

// Cmd+Backspace: delete to line start
pub fn delete_to_line_start(text string, layout Layout, cursor int) MutationResult {
    line_start := layout.move_cursor_line_start(cursor)

    mut sb := strings.new_builder(text.len)
    sb.write_string(text[..line_start])
    sb.write_string(text[cursor..])

    return MutationResult{
        new_text:     sb.str()
        cursor_pos:   line_start
        deleted_text: text[line_start..cursor]
        range_start:  line_start
        range_end:    cursor
    }
}
```

### Pattern 4: Change Event Callback
**What:** Notify app of text changes for undo/redo integration
**When to use:** After each mutation
**Example:**
```v
// Source: User decision from CONTEXT.md

pub struct TextChange {
pub:
    range_start int    // Byte offset where change begins
    range_end   int    // Byte offset where change ends (in old text)
    new_text    string // Text that replaced range
}

pub type ChangeCallback = fn (change TextChange)

// App registers callback
mut editor := Editor{
    on_change: fn (change TextChange) {
        // Push to undo stack, sync with external systems, etc.
        undo_stack.push(change)
    }
}

// After mutation, callback is invoked
fn (mut editor Editor) apply_mutation(result MutationResult) {
    editor.text = result.new_text
    editor.cursor = result.cursor_pos

    // Fire change event
    if editor.on_change != unsafe { nil } {
        editor.on_change(TextChange{
            range_start: result.range_start
            range_end:   result.range_end
            new_text:    result.new_text[result.range_start..result.range_start +
                         (result.range_end - result.range_start) + result.new_text.len -
                         editor.text.len]
        })
    }

    // Regenerate layout
    editor.layout = editor.ts.layout_text(editor.text, editor.cfg) or { return }
}
```

### Pattern 5: Batching Rapid Mutations
**What:** Coalesce multiple rapid changes into single change event
**When to use:** Holding backspace, rapid typing
**Example:**
```v
// Source: Debounce pattern from web development

const batch_timeout_ms = 100  // Batch mutations within 100ms window

struct MutationBatcher {
mut:
    pending_changes []TextChange
    last_mutation   i64  // time.now().unix_milli()
    original_start  int  // Start of first change in batch
    original_text   string
}

fn (mut batcher MutationBatcher) add_change(change TextChange, now i64) {
    if batcher.pending_changes.len == 0 || now - batcher.last_mutation > batch_timeout_ms {
        // Start new batch
        batcher.pending_changes = [change]
        batcher.original_start = change.range_start
    } else {
        // Merge into existing batch
        batcher.pending_changes << change
    }
    batcher.last_mutation = now
}

fn (mut batcher MutationBatcher) flush() ?TextChange {
    if batcher.pending_changes.len == 0 {
        return none
    }

    // Combine all changes into single event
    combined := TextChange{
        range_start: batcher.original_start
        range_end:   batcher.pending_changes[0].range_end
        new_text:    // accumulated result
    }
    batcher.pending_changes.clear()
    return combined
}
```

### Anti-Patterns to Avoid
- **Mutating inside VGlyph:** VGlyph renders, doesn't own text
- **Byte-level deletion:** Always use grapheme boundaries from LogAttr
- **Regenerating layout per keystroke without cache:** Cache invalidates automatically on text change
- **Blocking change events:** Fire async or batch, don't block editing
- **Index arithmetic after mutation:** Indices shift - always recalculate from fresh layout

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Grapheme cluster detection | Byte scanning | `Layout.move_cursor_left/right` | Unicode complex (emoji ZWJ sequences) |
| Word boundary detection | Space splitting | `Layout.move_cursor_word_left/right` | UAX#29 word boundaries |
| Line boundary detection | Newline scanning | `Layout.move_cursor_line_start/end` | Handles wrapped lines correctly |
| String building | `+` concatenation | `strings.Builder` | O(n) vs O(n^2) for multiple ops |
| Clipboard access | Platform APIs | v-gui pasteboard | User decision: v-gui handles |

**Key insight:** VGlyph already has grapheme-aware cursor movement from Phase 11. Deletion is
just "find target position, slice string". Don't reimplement boundary detection.

## Common Pitfalls

### Pitfall 1: Deleting Bytes Instead of Grapheme Clusters
**What goes wrong:** Backspace deletes one byte, corrupts multi-byte characters
**Why it happens:** Using `text.len - 1` instead of grapheme boundary
**How to avoid:** Always use `layout.move_cursor_left(cursor)` to find delete position
**Warning signs:** Emoji partially deleted, corrupted UTF-8, mojibake

### Pitfall 2: Stale Layout After Mutation
**What goes wrong:** Cursor positions, selection rects incorrect after text change
**Why it happens:** Using old Layout with new text
**How to avoid:** Regenerate layout immediately after text mutation
**Warning signs:** Cursor at wrong position, crash on get_cursor_pos

### Pitfall 3: Index Invalidation on Multi-Character Delete
**What goes wrong:** Selection anchor points to wrong position after delete
**Why it happens:** Anchor/cursor indices not adjusted after string shortens
**How to avoid:** Clear selection after mutation, or adjust indices by delta
**Warning signs:** Selection covers wrong range, extends past text end

### Pitfall 4: Forward Delete Grapheme Boundary
**What goes wrong:** Delete key removes wrong amount of text
**Why it happens:** Using `cursor + 1` instead of next grapheme boundary
**How to avoid:** Use `layout.move_cursor_right(cursor)` to find delete end
**Warning signs:** Delete key behavior differs from Backspace mirror

### Pitfall 5: Change Event Flooding
**What goes wrong:** Thousands of change events when holding backspace
**Why it happens:** Firing change event per keystroke without batching
**How to avoid:** Implement batching with timeout (user decision: batch rapid mutations)
**Warning signs:** Undo stack explodes, performance degrades during rapid edits

### Pitfall 6: Cut/Copy Without Selection Check
**What goes wrong:** Cut with no selection deletes nothing but returns empty string
**Why it happens:** Not checking `has_selection` before cut operation
**How to avoid:** Cut/Copy return `none` or empty string when no selection
**Warning signs:** Empty clipboard after cut, confusing user experience

## Code Examples

### Complete Mutation Handler for Editor Demo
```v
// Source: Extending editor_demo.v from Phase 12

fn handle_char_input(mut app EditorApp, e &gg.Event) {
    // Ignore control characters
    if e.char_code < 32 { return }

    // Convert to string
    mut char_str := ''
    runes := [rune(e.char_code)]
    char_str = runes.string()

    // Insert with selection replacement
    result := insert_text(app.text, app.layout, app.cursor_idx,
                         if app.has_selection { app.anchor_idx } else { app.cursor_idx },
                         char_str)

    // Apply mutation
    app.text = result.new_text
    app.cursor_idx = result.cursor_pos
    app.anchor_idx = result.cursor_pos
    app.has_selection = false

    // Regenerate layout
    app.layout = app.ts.layout_text(app.text, app.cfg) or { return }

    // Fire change event (if callback registered)
    if app.on_change != unsafe { nil } {
        app.batcher.add_change(TextChange{
            range_start: result.range_start
            range_end:   result.range_end
            new_text:    char_str
        }, time.now().unix_milli())
    }
}

fn handle_backspace(mut app EditorApp, modifiers u32) {
    cmd_held := (modifiers & u32(gg.Modifier.super)) != 0
    opt_held := (modifiers & u32(gg.Modifier.alt)) != 0

    // If selection active, delete selection
    if app.has_selection {
        sel_start := if app.cursor_idx < app.anchor_idx { app.cursor_idx } else { app.anchor_idx }
        sel_end := if app.cursor_idx < app.anchor_idx { app.anchor_idx } else { app.cursor_idx }

        mut sb := strings.new_builder(app.text.len)
        sb.write_string(app.text[..sel_start])
        sb.write_string(app.text[sel_end..])

        app.text = sb.str()
        app.cursor_idx = sel_start
        app.anchor_idx = sel_start
        app.has_selection = false
    } else if cmd_held {
        // Cmd+Backspace: delete to line start
        result := delete_to_line_start(app.text, app.layout, app.cursor_idx)
        app.text = result.new_text
        app.cursor_idx = result.cursor_pos
    } else if opt_held {
        // Option+Backspace: delete to word boundary
        result := delete_to_word_boundary(app.text, app.layout, app.cursor_idx)
        app.text = result.new_text
        app.cursor_idx = result.cursor_pos
    } else {
        // Plain Backspace: delete one grapheme cluster
        result := delete_backward(app.text, app.layout, app.cursor_idx)
        app.text = result.new_text
        app.cursor_idx = result.cursor_pos
    }

    // Regenerate layout
    app.layout = app.ts.layout_text(app.text, app.cfg) or { return }
}
```

### Copy/Cut/Paste API Pattern
```v
// Source: User decisions from CONTEXT.md

// Copy: VGlyph returns selected text, v-gui handles pasteboard
pub fn get_selected_text(text string, cursor int, anchor int, has_selection bool) string {
    if !has_selection { return '' }
    sel_start := if cursor < anchor { cursor } else { anchor }
    sel_end := if cursor < anchor { anchor } else { cursor }
    return text[sel_start..sel_end]
}

// Cut: returns text + performs delete
pub fn cut_selection(text string, layout Layout, cursor int, anchor int,
                     has_selection bool) (string, MutationResult) {
    if !has_selection {
        return '', MutationResult{ new_text: text, cursor_pos: cursor }
    }

    selected := get_selected_text(text, cursor, anchor, has_selection)

    sel_start := if cursor < anchor { cursor } else { anchor }
    sel_end := if cursor < anchor { anchor } else { cursor }

    mut sb := strings.new_builder(text.len)
    sb.write_string(text[..sel_start])
    sb.write_string(text[sel_end..])

    return selected, MutationResult{
        new_text:     sb.str()
        cursor_pos:   sel_start
        deleted_text: selected
        range_start:  sel_start
        range_end:    sel_end
    }
}

// Paste: uses generic insert_text (user decision: no separate paste method)
// v-gui calls: editor.insert_text(pasteboard.get_string())
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Byte-level editing | Grapheme cluster editing | Unicode 9+ | Correct emoji/CJK handling |
| Editor owns text | Renderer + Editor separation | Modern architecture | Clean separation of concerns |
| Sync change events | Batched/debounced events | Web/mobile editors | Better undo/redo, performance |
| Overwrite mode toggle | Insert-only | Modern editors | Simpler UX, user decision |

**Deprecated/outdated:**
- Overwrite mode: User decision - not implementing
- Auto-pairing in VGlyph: User decision - v-gui handles if wanted
- Rich text clipboard: User decision - plain text only

## Open Questions

1. **Layout regeneration timing?**
   - What we know: Text mutation invalidates layout, must regenerate
   - What's unclear: Immediate vs deferred regeneration
   - Recommendation: Immediate - simpler, deferred risks stale state
   - Claude's discretion per CONTEXT.md

2. **Callback signature exact form?**
   - What we know: Callback receives range + new text per user decision
   - What's unclear: Exact parameter types, optional vs required
   - Recommendation: `fn(range_start int, range_end int, new_text string)`
   - Claude's discretion per CONTEXT.md

3. **Batch window duration?**
   - What we know: User wants rapid mutations coalesced
   - What's unclear: Exact timeout value
   - Recommendation: 100ms window (standard debounce timing)
   - Claude's discretion per CONTEXT.md

## Sources

### Primary (HIGH confidence)
- VGlyph layout_query.v - Existing cursor/grapheme APIs verified in codebase
- VGlyph layout_types.v - Layout struct with LogAttr verified in codebase
- VGlyph editor_demo.v - Working cursor/selection implementation
- Phase 11/12 RESEARCH.md - Prior grapheme boundary decisions
- [V strings.Builder](https://modules.vlang.io/strings.html) - Official module documentation

### Secondary (MEDIUM confidence)
- [Debouncing patterns](https://www.geeksforgeeks.org/javascript/debouncing-in-javascript/) -
  Standard debounce implementation
- [Command pattern for undo](https://www.mattduck.com/undo-redo-text-editors) - Text editor
  undo/redo architectures

### Tertiary (LOW confidence)
- Web search results for V string manipulation - verified against official docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - V stdlib and existing VGlyph APIs verified
- Architecture: HIGH - Pattern follows Phase 11/12 and user decisions
- Pitfalls: HIGH - Common text editing issues well-documented
- Change event batching: MEDIUM - Standard pattern, timing tunable

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable domain)
