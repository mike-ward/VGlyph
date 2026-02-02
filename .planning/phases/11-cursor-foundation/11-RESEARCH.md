# Phase 11: Cursor Foundation - Research

**Researched:** 2026-02-02
**Domain:** Text cursor positioning and navigation
**Confidence:** HIGH

## Summary

Cursor foundation builds on existing VGlyph hit testing APIs (`get_closest_offset`, `hit_test`, `char_rects`)
and Pango cursor APIs (`pango_layout_get_cursor_pos`, `pango_layout_move_cursor_visually`,
`pango_layout_get_log_attrs_readonly`). The codebase already has partial cursor support in `editor_demo.v`
demonstrating click-to-position and selection, but lacks proper cursor geometry API and keyboard navigation.

Pango provides comprehensive cursor positioning via `pango_layout_get_cursor_pos` which returns a zero-width
rectangle at the byte index, with strong/weak positions for bidirectional text. Cursor movement via
`pango_layout_move_cursor_visually` automatically handles grapheme clusters (emoji, combining marks) - the
function moves by cursor positions, not characters. Word boundaries accessible via `PangoLogAttr` structure
(`is_word_start`, `is_word_end`, `is_cursor_position`) from `pango_layout_get_log_attrs_readonly`.

Key insight: The codebase already computes `char_rects` during layout which provides approximate cursor
geometry. For precise cursor positioning (especially bidi text), use Pango's `get_cursor_pos`. The
existing `editor_demo.v` shows the pattern: store cursor byte index, use Layout's query methods for
rendering position.

**Primary recommendation:** Use Pango cursor APIs for geometry/movement, expose as Layout methods.

## Standard Stack

No external libraries needed - all APIs available via existing Pango bindings.

### Core Pango APIs (to add bindings)
| API | Purpose | Already Bound |
|-----|---------|---------------|
| `pango_layout_get_cursor_pos` | Get cursor geometry at byte index | No |
| `pango_layout_move_cursor_visually` | Move cursor respecting bidi/graphemes | No |
| `pango_layout_get_log_attrs_readonly` | Get word/line boundaries | No |

### Existing VGlyph APIs (to leverage)
| API | Location | Purpose | Status |
|-----|----------|---------|--------|
| `Layout.get_closest_offset` | layout_query.v | Click-to-byte-index | Working |
| `Layout.hit_test` | layout_query.v | Point-to-byte-index | Working |
| `Layout.get_char_rect` | layout_query.v | Byte-index-to-rect | Working |
| `Layout.char_rects` | layout_types.v | All character boxes | Working |
| `Layout.lines` | layout_types.v | Line info (start_index, length) | Working |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pango cursor APIs | Manual char_rect traversal | Manual misses bidi, grapheme clusters |
| `move_cursor_visually` | Manual byte arithmetic | Breaks on emoji, bidi text |
| `get_log_attrs_readonly` | GLib-based `pango_break` | Layout version faster, already computed |

## Architecture Patterns

### Recommended API Surface
```v
// Add to Layout struct methods in layout_query.v

// Cursor position geometry
pub struct CursorPosition {
pub:
    x      f32
    y      f32
    height f32
}

// Get cursor geometry at byte index (for rendering cursor line)
pub fn (l Layout) get_cursor_pos(byte_index int) ?CursorPosition

// Move cursor by character (respects grapheme clusters)
pub fn (l Layout) move_cursor(byte_index int, direction CursorDirection) int

pub enum CursorDirection {
    left
    right
    up
    down
    word_left
    word_right
    line_start
    line_end
}
```

### Pattern 1: Transient Pango Layout for Cursor Ops
**What:** Some cursor APIs require the original PangoLayout, not the V Layout copy
**When to use:** `get_cursor_pos`, `move_cursor_visually`, `get_log_attrs_readonly`
**Example:**
```v
// Source: Pango documentation pattern
// Problem: V Layout is extracted copy, loses PangoLayout pointer
// Solution: Context method that recreates layout for cursor ops

pub fn (mut ctx Context) get_cursor_pos(text string, cfg TextConfig, byte_index int) ?CursorPosition {
    // Recreate PangoLayout (cheap if cached, or use stored pointer)
    layout := setup_pango_layout(mut ctx, text, cfg) or { return none }
    defer { C.g_object_unref(layout) }

    strong_pos := C.PangoRectangle{}
    weak_pos := C.PangoRectangle{}
    C.pango_layout_get_cursor_pos(layout, byte_index, &strong_pos, &weak_pos)

    // Convert Pango units to pixels
    pixel_scale := 1.0 / (f32(pango_scale) * ctx.scale_factor)
    return CursorPosition{
        x:      f32(strong_pos.x) * pixel_scale
        y:      f32(strong_pos.y) * pixel_scale
        height: f32(strong_pos.height) * pixel_scale
    }
}
```

### Pattern 2: Cached Cursor Metadata in Layout
**What:** Store cursor-relevant data during layout build, avoid recreating PangoLayout
**When to use:** When cursor ops frequent, PangoLayout recreation too expensive
**Example:**
```v
// Add to Layout struct
pub struct Layout {
pub mut:
    // Existing fields...
    log_attrs []LogAttr  // NEW: cursor positions, word boundaries
}

pub struct LogAttr {
pub:
    is_cursor_position bool
    is_word_start      bool
    is_word_end        bool
    is_line_break      bool
}

// Populate during build_layout_from_pango
fn extract_log_attrs(layout &C.PangoLayout, text string) []LogAttr {
    mut n_attrs := int(0)
    attrs_ptr := C.pango_layout_get_log_attrs_readonly(layout, &n_attrs)
    // n_attrs is text.len + 1 (position before first and after last char)

    mut attrs := []LogAttr{cap: n_attrs}
    for i in 0 .. n_attrs {
        pango_attr := unsafe { attrs_ptr[i] }
        attrs << LogAttr{
            is_cursor_position: pango_attr.is_cursor_position != 0
            is_word_start:      pango_attr.is_word_start != 0
            is_word_end:        pango_attr.is_word_end != 0
            is_line_break:      pango_attr.is_line_break != 0
        }
    }
    return attrs
}
```

### Pattern 3: Cursor Movement via LogAttr Scan
**What:** Use cached log_attrs to find next valid cursor position
**When to use:** Keyboard navigation (arrow keys, word jump)
**Example:**
```v
// Move right by one grapheme cluster
pub fn (l Layout) move_cursor_right(byte_index int) int {
    // Find next is_cursor_position after current index
    for i in (byte_index + 1) .. l.log_attrs.len {
        if l.log_attrs[i].is_cursor_position {
            return i
        }
    }
    return byte_index  // At end, don't move
}

// Move to next word start
pub fn (l Layout) move_cursor_word_right(byte_index int) int {
    for i in (byte_index + 1) .. l.log_attrs.len {
        if l.log_attrs[i].is_word_start {
            return i
        }
    }
    return l.log_attrs.len - 1  // Move to end
}
```

### Anti-Patterns to Avoid
- **Byte-level cursor movement:** Breaking grapheme clusters (cursor lands inside emoji)
- **Manual word detection via spaces:** Unicode word boundaries complex, use Pango LogAttr
- **Recreating PangoLayout every cursor movement:** Cache log_attrs in Layout struct
- **Ignoring bidi text:** Use strong_pos from `get_cursor_pos`, not manual calculation

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Grapheme cluster detection | Byte-by-byte scan | `pango_layout_get_log_attrs_readonly` | Unicode Standard complex (emoji ZWJ, combining marks) |
| Word boundary detection | Space-splitting | `LogAttr.is_word_start/end` | Unicode UAX#29 defines words, not spaces |
| Cursor geometry | Manual char_rect lookup | `pango_layout_get_cursor_pos` | Handles bidi, zero-width chars, correct baseline |
| Visual cursor movement | Index arithmetic | `pango_layout_move_cursor_visually` | Handles bidi reordering correctly |

**Key insight:** Cursor positioning in Unicode text is subtle. Emoji like "family" can be 11+
codepoints but one grapheme. Pango implements UAX#29, use it.

## Common Pitfalls

### Pitfall 1: Breaking Grapheme Clusters
**What goes wrong:** Cursor lands inside emoji sequence (e.g., between skin tone modifier and base)
**Why it happens:** Moving cursor by bytes or codepoints instead of grapheme clusters
**How to avoid:** Use `pango_layout_move_cursor_visually` or scan `is_cursor_position` in LogAttr
**Warning signs:** Cursor appears in strange positions on emoji, combining characters split

### Pitfall 2: Wrong Cursor Geometry for Bidi Text
**What goes wrong:** Cursor appears at wrong position in mixed LTR/RTL text
**Why it happens:** Using char_rect.x directly without considering bidi reordering
**How to avoid:** Use `pango_layout_get_cursor_pos` which returns strong/weak cursor positions
**Warning signs:** Cursor jumps unexpectedly when navigating Hebrew/Arabic mixed with English

### Pitfall 3: PangoLayout Lifetime
**What goes wrong:** Crash or incorrect results when calling Pango cursor APIs
**Why it happens:** V Layout struct extracted from transient PangoLayout which is freed
**How to avoid:** Either cache cursor data during build, or recreate PangoLayout for cursor ops
**Warning signs:** Segfault in `pango_layout_get_cursor_pos`, corrupted results

### Pitfall 4: Off-by-One in LogAttr Array
**What goes wrong:** Array index out of bounds, missing last position
**Why it happens:** LogAttr array has N+1 elements for N characters
**How to avoid:** Document that log_attrs[i] corresponds to position before character i
**Warning signs:** Crash at text end, cursor can't reach final position

### Pitfall 5: Line Navigation Complexity
**What goes wrong:** Up/Down arrow moves to wrong line, misses wrapped text
**Why it happens:** Lines in Layout are visual lines (after wrap), not logical paragraphs
**How to avoid:** Use Layout.lines array, find line containing cursor, navigate by x-coordinate
**Warning signs:** Cursor moves incorrectly in wrapped text, skips lines

## Code Examples

### Adding Pango Cursor Bindings (c_bindings.v)
```v
// Source: Pango documentation - to add to c_bindings.v

// LogAttr structure for cursor/word boundaries
@[typedef]
pub struct C.PangoLogAttr {
pub:
    // Bitfields packed as u32 - access individual flags via bit masking
    // is_line_break : 1
    // is_mandatory_break : 1
    // is_char_break : 1
    // is_white : 1
    // is_cursor_position : 1  // <- Key for cursor movement
    // is_word_start : 1       // <- Key for word movement
    // is_word_end : 1         // <- Key for word movement
    // is_sentence_boundary : 1
    // is_sentence_start : 1
    // is_sentence_end : 1
    // is_backspace_deletes_character : 1
    // is_expandable_space : 1
    // is_word_boundary : 1
    flags u32
}

// Flag extraction helpers
const pango_log_attr_is_cursor_position = 0x10  // bit 4
const pango_log_attr_is_word_start = 0x20       // bit 5
const pango_log_attr_is_word_end = 0x40         // bit 6
const pango_log_attr_is_line_break = 0x01       // bit 0

fn C.pango_layout_get_cursor_pos(&C.PangoLayout, int, &C.PangoRectangle, &C.PangoRectangle)
fn C.pango_layout_move_cursor_visually(&C.PangoLayout, bool, int, int, int, &int, &int)
fn C.pango_layout_get_log_attrs_readonly(&C.PangoLayout, &int) &C.PangoLogAttr
```

### Cursor Geometry from Existing CharRects (Fallback)
```v
// Source: editor_demo.v pattern - existing approach
// Use when Pango cursor APIs unavailable or as quick approximation

pub fn (l Layout) get_cursor_pos_approx(byte_index int) ?CursorPosition {
    // Try to find exact char rect
    if rect := l.get_char_rect(byte_index) {
        // Cursor is at left edge of character
        return CursorPosition{
            x:      rect.x
            y:      rect.y
            height: rect.height
        }
    }

    // Fallback: find containing line, use line rect
    for line in l.lines {
        if byte_index >= line.start_index && byte_index <= line.start_index + line.length {
            if byte_index == line.start_index + line.length {
                // At end of line
                return CursorPosition{
                    x:      line.rect.x + line.rect.width
                    y:      line.rect.y
                    height: line.rect.height
                }
            }
            return CursorPosition{
                x:      line.rect.x
                y:      line.rect.y
                height: line.rect.height
            }
        }
    }
    return none
}
```

### Keyboard Navigation Handler Pattern
```v
// Source: Standard text editor pattern

fn handle_key_navigation(mut cursor int, layout Layout, key gg.KeyCode, modifiers u32) {
    cmd_held := (modifiers & C.SAPP_MODIFIER_SUPER) != 0  // macOS Cmd key

    match key {
        .left {
            if cmd_held {
                cursor = layout.move_cursor_word_left(cursor)
            } else {
                cursor = layout.move_cursor_left(cursor)
            }
        }
        .right {
            if cmd_held {
                cursor = layout.move_cursor_word_right(cursor)
            } else {
                cursor = layout.move_cursor_right(cursor)
            }
        }
        .home {
            cursor = layout.move_cursor_line_start(cursor)
        }
        .end {
            cursor = layout.move_cursor_line_end(cursor)
        }
        .up {
            cursor = layout.move_cursor_up(cursor)
        }
        .down {
            cursor = layout.move_cursor_down(cursor)
        }
        else {}
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual char iteration | Pango LogAttr | Unicode 14+ | Correct emoji/combining mark handling |
| Single cursor | Strong/weak cursor | Bidi support | Split cursor for mixed-direction text |
| Byte-level movement | Grapheme-level | Unicode Standard | User-perceived character movement |

**Current editor_demo.v limitations:**
- Uses `get_closest_offset` for click (correct)
- Manual cursor rendering via line rect lookup (could use `get_cursor_pos`)
- No keyboard navigation support
- No word/line boundary movement

**What Phase 11 adds:**
- `get_cursor_pos` API for precise cursor geometry
- `move_cursor` APIs for character/word/line navigation
- LogAttr caching for efficient boundary queries
- Grapheme cluster respect via Pango APIs

## Open Questions

1. **Cache log_attrs or recreate PangoLayout?**
   - What we know: PangoLayout recreation has overhead, log_attrs array ~4 bytes per char
   - What's unclear: Memory tradeoff for large documents
   - Recommendation: Cache log_attrs in Layout, regenerate on text change

2. **Strong vs weak cursor for bidi?**
   - What we know: Pango returns both positions for split cursor rendering
   - What's unclear: Should VGlyph expose both or just strong?
   - Recommendation: Return strong by default, optional weak in CursorPosition struct

3. **Up/Down arrow x-position memory?**
   - What we know: Editors remember x when moving up/down, not covered by Pango
   - What's unclear: Should Layout track "preferred x" or app responsibility?
   - Recommendation: App tracks preferred_x, Layout provides line-finding APIs

## Sources

### Primary (HIGH confidence)
- [Pango.Layout.get_cursor_pos](https://docs.gtk.org/Pango/method.Layout.get_cursor_pos.html) - Official cursor geometry API
- [Pango.Layout.move_cursor_visually](https://docs.gtk.org/Pango/method.Layout.move_cursor_visually.html) - Visual cursor movement
- [Pango.LogAttr](https://docs.gtk.org/Pango/struct.LogAttr.html) - Logical attributes for word/cursor boundaries
- [Pango.Layout class](https://docs.gtk.org/Pango/class.Layout.html) - Full Layout API reference
- VGlyph layout_query.v - Existing hit testing implementation
- VGlyph editor_demo.v - Existing cursor/selection demo

### Secondary (MEDIUM confidence)
- [UAX #29: Unicode Text Segmentation](http://www.unicode.org/reports/tr29/) - Grapheme cluster standard
- [W3C Cursor Movement and Deletion](https://w3c.github.io/i18n-drafts/questions/qa-backwards-deletion.en.html) - Best practices
- [Xi Editor Rope Science](https://xi-editor.io/docs/rope_science_03.html) - Grapheme boundary implementation

### Tertiary (LOW confidence)
- [Mitchell Hashimoto - Grapheme Clusters in Terminals](https://mitchellh.com/writing/grapheme-clusters-in-terminals) - Practical emoji challenges
- [Apple Characters and Grapheme Clusters](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Strings/Articles/stringsClusters.html) - Platform perspective

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Pango APIs well-documented, codebase has hit testing foundation
- Architecture: HIGH - Clear pattern from existing layout_query.v and editor_demo.v
- Pitfalls: HIGH - Unicode cursor positioning well-documented problem domain
- LogAttr bitfields: MEDIUM - Need to verify exact bit positions in PangoLogAttr struct

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable domain, Pango API stable)
