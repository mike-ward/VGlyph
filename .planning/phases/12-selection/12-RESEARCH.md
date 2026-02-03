# Phase 12: Selection - Research

**Researched:** 2026-02-02
**Domain:** Text selection (mouse/keyboard), multi-click word/paragraph selection, highlight rendering
**Confidence:** HIGH

## Summary

Text selection builds on Phase 11's cursor foundation and existing selection APIs (`get_selection_rects`,
already demoed in `editor_demo.v`). Core challenge is state management: tracking anchor/cursor positions,
handling Shift modifier for extension, auto-scroll during drag, multi-click timing, and rendering dimmed
highlights on focus loss.

Pango provides word boundaries via `LogAttr.is_word_start/end` (already cached in Phase 11). Paragraph
detection needs custom logic: scan for empty lines (consecutive newlines). Standard pattern: anchor-focus
selection state where anchor is fixed at initial click, focus moves with mouse/keyboard. Shift-click/arrow
extends from anchor, not cursor. Click without Shift clears selection.

Selection rendering uses semi-transparent rectangles from `get_selection_rects`. Standard colors: blue-ish
selection (VSCode: `#264F78` active, `#3A3D41` inactive at ~50% opacity). Auto-scroll when dragging past
text area edge: accelerating speed based on distance from edge, typical implementation scrolls on timer
(~100ms) with speed multiplier based on edge distance.

**Primary recommendation:** State machine with anchor/focus indices, modifier-aware event handlers,
timer-based auto-scroll with distance-based acceleration.

## Standard Stack

No external libraries needed - uses existing VGlyph/Pango APIs and gg event system.

### Core VGlyph APIs (existing)
| API | Location | Purpose | Status |
|-----|----------|---------|--------|
| `Layout.get_selection_rects` | layout_query.v | Get highlight geometry | Working |
| `Layout.get_closest_offset` | layout_query.v | Click-to-byte-index | Working |
| `Layout.move_cursor_*` | layout_query.v | Keyboard navigation | Phase 11 |
| `Layout.log_attrs` | layout_types.v | Word boundaries | Phase 11 |
| `Layout.lines` | layout_types.v | Line metadata | Working |

### gg Event APIs (existing)
| Event Type | Field | Purpose |
|-----------|-------|---------|
| `.mouse_down` | `mouse_x`, `mouse_y` | Selection anchor |
| `.mouse_move` | `mouse_x`, `mouse_y` | Drag selection |
| `.mouse_up` | - | End drag |
| `.key_down` | `key_code`, `modifiers` | Keyboard selection |

### Modifier Keys (gg.Modifier enum)
| Modifier | Bit Mask | macOS Key | Purpose |
|----------|----------|-----------|---------|
| `.shift` | 1 << 0 | Shift | Extend selection |
| `.ctrl` | 1 << 1 | Ctrl | (unused) |
| `.alt` | 1 << 2 | Option | Word-snap drag |
| `.super` | 1 << 3 | Cmd | Word movement |

### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| gg.draw_rect_filled | - | Render selection rects | Highlight rendering |
| time module | stdlib | Double-click timing, auto-scroll timer | Multi-click, drag scroll |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Anchor-focus state | Single range (start, end) | Can't track direction, breaks Shift-click extension |
| Timer auto-scroll | Mouse move frequency | Inconsistent speed, Raymond Chen "wiggle bug" |
| Pango word boundaries | Space-splitting | Breaks on punctuation, CJK text |

## Architecture Patterns

### Recommended State Structure
```v
// Selection state in app struct
struct EditorApp {
mut:
    // Cursor position (from Phase 11)
    cursor_idx int

    // Selection state
    anchor_idx       int  // Fixed point where selection started
    has_selection    bool // Whether selection active
    is_dragging      bool // Whether mouse drag in progress

    // Multi-click tracking
    last_click_time  i64  // time.now().unix_milli()
    click_count      int  // 1, 2, 3 for single/double/triple

    // Auto-scroll state
    scroll_offset    f32
    scroll_velocity  f32  // Pixels per scroll tick
    scroll_timer_id  int  // Timer handle (if gg supports)
}
```

### Pattern 1: Anchor-Focus Selection State
**What:** Track fixed anchor and moving focus separately, derive range from them
**When to use:** All selection operations (click-drag, Shift-click, keyboard)
**Example:**
```v
// Initialize on mouse_down (no Shift)
fn start_selection(mut app EditorApp, byte_idx int) {
    app.anchor_idx = byte_idx
    app.cursor_idx = byte_idx
    app.has_selection = false
    app.is_dragging = true
}

// Update on mouse_move (dragging)
fn update_selection(mut app EditorApp, byte_idx int) {
    if !app.is_dragging { return }
    app.cursor_idx = byte_idx
    app.has_selection = (byte_idx != app.anchor_idx)
}

// Extend on Shift-click
fn extend_selection(mut app EditorApp, byte_idx int) {
    // Keep anchor fixed, move cursor
    app.cursor_idx = byte_idx
    app.has_selection = (byte_idx != app.anchor_idx)
}

// Get ordered range for rendering
fn get_selection_range(app EditorApp) (int, int) {
    if !app.has_selection { return 0, 0 }
    start := if app.anchor_idx < app.cursor_idx { app.anchor_idx } else { app.cursor_idx }
    end := if app.anchor_idx < app.cursor_idx { app.cursor_idx } else { app.anchor_idx }
    return start, end
}
```

### Pattern 2: Multi-Click Word/Paragraph Selection
**What:** Track click timing, snap selection to word/paragraph boundaries on double/triple-click
**When to use:** mouse_down events
**Example:**
```v
const double_click_ms = 400  // User decision: fixed 400ms

fn handle_mouse_down(mut app EditorApp, e gg.Event) {
    idx := app.layout.get_closest_offset(e.mouse_x - offset_x, e.mouse_y - offset_y)
    now := time.now().unix_milli()
    time_since_last := now - app.last_click_time

    // Update click count
    if time_since_last <= double_click_ms {
        app.click_count++
    } else {
        app.click_count = 1
    }
    app.last_click_time = now

    match app.click_count {
        1 {
            // Single click: normal anchor
            app.anchor_idx = idx
            app.cursor_idx = idx
            app.has_selection = false
        }
        2 {
            // Double click: select word
            word_range := find_word_at_index(app.layout, idx)
            app.anchor_idx = word_range.start
            app.cursor_idx = word_range.end
            app.has_selection = true
        }
        3 {
            // Triple click: select paragraph
            para_range := find_paragraph_at_index(app.layout, app.text, idx)
            app.anchor_idx = para_range.start
            app.cursor_idx = para_range.end
            app.has_selection = true
        }
        else {
            app.click_count = 1  // Reset after triple
        }
    }
    app.is_dragging = true
}

// Find word boundaries using Pango LogAttr
fn find_word_at_index(layout Layout, idx int) (int, int) {
    // Scan backwards for word_start
    mut start := idx
    for i := idx - 1; i >= 0; i-- {
        attr_idx := layout.log_attr_by_index[i] or { break }
        if layout.log_attrs[attr_idx].is_word_start {
            start = i
            break
        }
    }

    // Scan forward for word_end (or next word_start)
    mut end := idx
    for i := idx + 1; i < layout.log_attrs.len; i++ {
        attr_idx := layout.log_attr_by_index[i] or { break }
        if layout.log_attrs[attr_idx].is_word_start {
            end = i
            break
        }
    }

    return start, end
}

// Find paragraph boundaries (until empty line)
fn find_paragraph_at_index(layout Layout, text string, idx int) (int, int) {
    // Scan backwards to start of paragraph or empty line
    mut start := 0
    for i := idx - 1; i >= 0; i-- {
        if text[i] == `\n` {
            // Check if next char also newline (empty line)
            if i > 0 && text[i-1] == `\n` {
                start = i + 1
                break
            }
            // Check if this is start of text
            if i == 0 {
                start = 0
                break
            }
        }
    }

    // Scan forward to end of paragraph or empty line
    mut end := text.len
    for i := idx; i < text.len - 1; i++ {
        if text[i] == `\n` && text[i+1] == `\n` {
            end = i + 1
            break
        }
    }

    return start, end
}
```

### Pattern 3: Auto-Scroll on Drag Past Edge
**What:** Scroll viewport when mouse dragged outside text area, accelerate speed with distance
**When to use:** mouse_move events during drag
**Example:**
```v
const scroll_margin = 20.0        // Pixels from edge to trigger scroll
const scroll_base_speed = 2.0     // Base pixels per tick
const scroll_acceleration = 0.1   // Speed multiplier per pixel past margin

fn handle_mouse_move(mut app EditorApp, e gg.Event) {
    if !app.is_dragging { return }

    // Update selection
    idx := app.layout.get_closest_offset(e.mouse_x - offset_x, e.mouse_y - offset_y)
    app.cursor_idx = idx
    app.has_selection = (idx != app.anchor_idx)

    // Check if near edge for auto-scroll
    text_area_top := offset_y
    text_area_bottom := offset_y + app.layout.height

    if e.mouse_y < text_area_top - scroll_margin {
        // Scroll up
        distance := text_area_top - scroll_margin - e.mouse_y
        app.scroll_velocity = -(scroll_base_speed + distance * scroll_acceleration)
    } else if e.mouse_y > text_area_bottom + scroll_margin {
        // Scroll down
        distance := e.mouse_y - (text_area_bottom + scroll_margin)
        app.scroll_velocity = scroll_base_speed + distance * scroll_acceleration
    } else {
        app.scroll_velocity = 0
    }
}

// In frame function or timer callback (100ms interval)
fn apply_auto_scroll(mut app EditorApp) {
    if app.scroll_velocity != 0 && app.is_dragging {
        app.scroll_offset += app.scroll_velocity
        // Clamp to valid range
        if app.scroll_offset < 0 { app.scroll_offset = 0 }
        // Re-query mouse position to update selection
        // (requires storing last mouse coords or triggering mouse_move)
    }
}
```

### Pattern 4: Keyboard Selection Extension
**What:** Shift+Arrow extends selection from anchor, Arrow without Shift collapses to direction
**When to use:** key_down events with cursor movement keys
**Example:**
```v
fn handle_key_down(mut app EditorApp, e gg.Event) {
    shift_held := (e.modifiers & u32(gg.Modifier.shift)) != 0
    cmd_held := (e.modifiers & u32(gg.Modifier.super)) != 0

    // Store old cursor for shift logic
    old_cursor := app.cursor_idx

    // Move cursor (existing Phase 11 navigation)
    match e.key_code {
        .left {
            if cmd_held {
                app.cursor_idx = app.layout.move_cursor_word_left(app.cursor_idx)
            } else {
                app.cursor_idx = app.layout.move_cursor_left(app.cursor_idx)
            }
        }
        .right {
            if cmd_held {
                app.cursor_idx = app.layout.move_cursor_word_right(app.cursor_idx)
            } else {
                app.cursor_idx = app.layout.move_cursor_right(app.cursor_idx)
            }
        }
        // ... up/down/home/end similar
        else { return }
    }

    // Handle selection state
    if shift_held {
        // Extend selection from anchor
        if !app.has_selection {
            app.anchor_idx = old_cursor
        }
        app.has_selection = (app.cursor_idx != app.anchor_idx)
    } else {
        // Collapse selection to direction
        if app.has_selection {
            // Left collapses to start, right to end
            if e.key_code == .left {
                app.cursor_idx = if app.anchor_idx < old_cursor { app.anchor_idx } else { old_cursor }
            } else if e.key_code == .right {
                app.cursor_idx = if app.anchor_idx > old_cursor { app.anchor_idx } else { old_cursor }
            }
        }
        app.has_selection = false
        app.anchor_idx = app.cursor_idx
    }
}
```

### Pattern 5: Focus-Aware Highlight Rendering
**What:** Render selection with different colors for active/inactive window
**When to use:** frame function, rendering selection rects
**Example:**
```v
const selection_color_active = gg.Color{38, 79, 120, 128}    // VSCode blue ~50% opacity
const selection_color_inactive = gg.Color{58, 61, 65, 128}  // Gray ~50% opacity

fn draw_selection(app EditorApp, has_focus bool) {
    if !app.has_selection { return }

    start, end := get_selection_range(app)
    rects := app.layout.get_selection_rects(start, end)

    color := if has_focus { selection_color_active } else { selection_color_inactive }

    for r in rects {
        app.gg.draw_rect_filled(
            offset_x + r.x,
            offset_y + r.y,
            r.width,
            r.height,
            color
        )
    }
}
```

### Anti-Patterns to Avoid
- **Single range without anchor/focus:** Can't determine selection direction, breaks Shift-click extension
- **Collapsing selection on any key:** Should only collapse on arrow without Shift, not on character input
- **Recreating selection on every mouse_move:** State machine approach avoids re-parsing click type
- **Synchronous scroll in mouse_move:** Causes frame drops, use timer/frame callback instead

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Word boundary detection | Scan for spaces | `LogAttr.is_word_start/end` | Handles punctuation, CJK, emoji correctly |
| Grapheme cluster selection | Byte-based ranges | Phase 11 cursor positions | Selection endpoints must be valid cursor positions |
| Double-click timing | Custom debounce | Platform standard (400ms) | User muscle memory, accessibility |
| Selection rectangle geometry | Manual line scanning | `get_selection_rects` | Handles wrapping, bidi, line heights |
| Paragraph detection | Regex line splitting | Manual newline scan | Simple, explicit, no regex overhead |

**Key insight:** Selection is cursor navigation + state tracking. Don't rebuild cursor logic, extend Phase 11.

## Common Pitfalls

### Pitfall 1: Shift-Click Extends from Cursor Instead of Anchor
**What goes wrong:** Shift-clicking unexpectedly shrinks selection or selects wrong range
**Why it happens:** Using cursor position as selection base instead of fixed anchor
**How to avoid:** Always extend from anchor position when Shift held, anchor set on first click (no Shift)
**Warning signs:** Selection "jumps" when Shift-clicking, can't extend selection backwards

### Pitfall 2: Arrow Keys Don't Collapse Selection Correctly
**What goes wrong:** Left arrow jumps to selection start even when cursor at end
**Why it happens:** Not considering selection direction when collapsing
**How to avoid:** Left collapses to min(anchor, cursor), right to max(anchor, cursor)
**Warning signs:** Cursor appears at wrong end of selection after arrow key

### Pitfall 3: Multi-Click Selection Breaks on Whitespace
**What goes wrong:** Double-clicking space selects nothing or adjacent word inconsistently
**Why it happens:** Word boundary logic doesn't handle "click between words" case
**How to avoid:** User decision: snap to adjacent word when clicking whitespace (scan left/right for nearest word)
**Warning signs:** Can't select words near spaces, inconsistent behavior

### Pitfall 4: Auto-Scroll Speed Inconsistent
**What goes wrong:** Scrolling too slow or too fast, or speed varies based on mouse movement
**Why it happens:** Raymond Chen's "wiggle bug" - mouse_move events trigger extra scrolls
**How to avoid:** Timer-based scroll with velocity calculation, clamp scroll rate, account for elapsed time
**Warning signs:** Wiggling mouse makes scroll faster, scroll speed unpredictable

### Pitfall 5: Selection Rendering Obscures Text
**What goes wrong:** Can't read selected text, especially with syntax highlighting
**Why it happens:** Opaque selection background or wrong color choice
**How to avoid:** Semi-transparent selection (~50% opacity), sufficient contrast with background
**Warning signs:** Selected text illegible, color conflicts with syntax highlighting

### Pitfall 6: Focus State Not Tracked
**What goes wrong:** Selection stays bright blue when window loses focus
**Why it happens:** Not subscribing to focus_lost/focus_gained events or not tracking state
**How to avoid:** Track has_focus bool, render with dimmed color when false
**Warning signs:** Selection looks active in background windows

### Pitfall 7: Click Inside Selection Doesn't Clear
**What goes wrong:** Clicking inside selection extends it instead of clearing
**Why it happens:** User decision was "click inside starts new selection", needs explicit check
**How to avoid:** On mouse_down, check if click inside current selection range, clear if so
**Warning signs:** Can't deselect by clicking selected text

## Code Examples

### Complete Selection Event Handler
```v
// Source: Standard text editor pattern combining all decisions

fn event_handler(e &gg.Event, mut app EditorApp) {
    offset_x := f32(50)
    offset_y := f32(50)

    match e.typ {
        .mouse_down {
            mx := e.mouse_x - offset_x
            my := e.mouse_y - offset_y
            idx := app.layout.get_closest_offset(mx, my)

            shift_held := (e.modifiers & u32(gg.Modifier.shift)) != 0
            alt_held := (e.modifiers & u32(gg.Modifier.alt)) != 0

            // Multi-click detection
            now := time.now().unix_milli()
            if now - app.last_click_time <= double_click_ms {
                app.click_count++
            } else {
                app.click_count = 1
            }
            app.last_click_time = now

            // Handle based on modifiers and click count
            if shift_held {
                // Extend from anchor
                app.cursor_idx = idx
                app.has_selection = (idx != app.anchor_idx)
            } else {
                // Check if clicking inside existing selection
                if app.has_selection {
                    start, end := get_selection_range(app)
                    if idx >= start && idx <= end {
                        // Clear selection, reposition cursor
                        app.anchor_idx = idx
                        app.cursor_idx = idx
                        app.has_selection = false
                        app.is_dragging = true
                        return
                    }
                }

                // New selection based on click count
                match app.click_count {
                    2 {
                        // Word selection
                        start, end := find_word_at_index(app.layout, idx)
                        app.anchor_idx = start
                        app.cursor_idx = end
                        app.has_selection = true
                    }
                    3 {
                        // Paragraph selection
                        start, end := find_paragraph_at_index(app.layout, app.text, idx)
                        app.anchor_idx = start
                        app.cursor_idx = end
                        app.has_selection = true
                    }
                    else {
                        // Single click
                        app.anchor_idx = idx
                        app.cursor_idx = idx
                        app.has_selection = false
                    }
                }
            }

            app.is_dragging = true
            app.word_snap_mode = alt_held  // Option+drag snaps to words
        }

        .mouse_move {
            if !app.is_dragging { return }

            mx := e.mouse_x - offset_x
            my := e.mouse_y - offset_y
            mut idx := app.layout.get_closest_offset(mx, my)

            // Word-snap mode (Option held during drag)
            if app.word_snap_mode {
                // Snap to word boundary
                start, end := find_word_at_index(app.layout, idx)
                // Use closer boundary
                idx = if idx - start < end - idx { start } else { end }
            }

            app.cursor_idx = idx
            app.has_selection = (idx != app.anchor_idx)

            // Auto-scroll calculation
            text_area_top := offset_y
            text_area_bottom := offset_y + app.layout.height

            if e.mouse_y < text_area_top - scroll_margin {
                distance := text_area_top - scroll_margin - e.mouse_y
                app.scroll_velocity = -(scroll_base_speed + distance * scroll_acceleration)
            } else if e.mouse_y > text_area_bottom + scroll_margin {
                distance := e.mouse_y - (text_area_bottom + scroll_margin)
                app.scroll_velocity = scroll_base_speed + distance * scroll_acceleration
            } else {
                app.scroll_velocity = 0
            }
        }

        .mouse_up {
            app.is_dragging = false
            app.word_snap_mode = false
            app.scroll_velocity = 0
        }

        .key_down {
            // Keyboard selection handled separately (Pattern 4)
            handle_key_selection(mut app, e)
        }

        else {}
    }
}
```

### Cmd+Shift+Arrow Word Selection with Trailing Space
```v
// Source: macOS text editing convention
// User decision: Cmd+Shift+Arrow includes trailing space

fn move_cursor_word_right_with_space(layout Layout, byte_index int) int {
    // Get next word start (Phase 11 API)
    mut next_word := layout.move_cursor_word_right(byte_index)

    // Scan forward past whitespace to include trailing space
    for i := next_word; i < layout.log_attrs.len; i++ {
        attr_idx := layout.log_attr_by_index[i] or { break }
        attr := layout.log_attrs[attr_idx]

        // Stop at next non-whitespace
        if !attr.is_white && attr.is_cursor_position {
            return i
        }
    }

    return next_word
}

// In keyboard handler
if cmd_held && shift_held && e.key_code == .right {
    app.cursor_idx = move_cursor_word_right_with_space(app.layout, app.cursor_idx)
    if !app.has_selection {
        app.anchor_idx = old_cursor
    }
    app.has_selection = (app.cursor_idx != app.anchor_idx)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single range | Anchor-focus pairs | ~2000s | Enables selection direction tracking |
| Opaque highlight | Semi-transparent | ~2010s | Readable selected text |
| Fixed scroll speed | Distance-based acceleration | ~1990s Windows | Responsive to user impatience |
| Line selection (triple-click) | Paragraph selection | ~2000s | More useful for prose editing |

**Deprecated/outdated:**
- Fixed double-click timing without accessibility - modern editors use platform settings
- Dragging selected text to move - user decision: click inside clears selection instead

## Open Questions

1. **gg focus events available?**
   - What we know: Need to track window focus for dimmed highlights
   - What's unclear: Does gg expose focus_gained/focus_lost events?
   - Recommendation: Check gg docs, fallback: always render active color if no focus API

2. **Auto-scroll timer mechanism?**
   - What we know: Need periodic callback during drag (100ms typical)
   - What's unclear: Does gg provide timer API or should we use frame_fn?
   - Recommendation: Use frame_fn with time delta, check if dragging and apply scroll

3. **Double-click on whitespace - which word?**
   - What we know: User decision says "snap to adjacent word"
   - What's unclear: Left word or right word priority?
   - Recommendation: Scan both directions, pick nearest word boundary

4. **Selection persistence during layout rebuild?**
   - What we know: Text edits trigger layout rebuild, byte indices shift
   - What's unclear: Phase 12 scope or Phase 13 (editing)?
   - Recommendation: Phase 12 assumes static text, Phase 13 handles index adjustment

## Sources

### Primary (HIGH confidence)
- [Pango.LogAttr](https://docs.gtk.org/Pango/struct.LogAttr.html) - Word boundary flags
- [VSCode Theme Colors](https://code.visualstudio.com/api/references/theme-color) - Selection color standards
- [Microsoft Auto-scroll Blog](https://devblogs.microsoft.com/oldnewthing/20210126-00/?p=104759) - Auto-scroll timing issues
- VGlyph layout_query.v - Existing `get_selection_rects` implementation
- VGlyph editor_demo.v - Existing selection demo (lines 162-171)
- Phase 11 research - Cursor navigation foundation

### Secondary (MEDIUM confidence)
- [Draft.js SelectionState](https://draftjs.org/docs/api-reference-selection-state/) - Anchor/focus pattern
- [Slate Locations](https://docs.slatejs.org/concepts/03-locations) - Modern selection state design
- [Mozilla Bug 32807](https://bugzilla.mozilla.org/show_bug.cgi?id=32807) - Triple-click paragraph vs line
- [Mac Text Selection Shortcuts](https://macmost.com/mac-text-selection-shortcuts.html) - macOS conventions

### Tertiary (LOW confidence)
- [Triple-click Wikipedia](https://en.wikipedia.org/wiki/Triple-click) - General multi-click behavior
- [WCAG Focus Appearance](https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance) - Accessibility (focus indicators, not selection)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - VGlyph APIs exist, gg events well-defined
- Architecture: HIGH - Anchor-focus pattern is industry standard, user decisions clear
- Pitfalls: HIGH - Selection edge cases well-documented in editor bug trackers
- Auto-scroll: MEDIUM - Implementation details vary, no single standard
- Focus events: LOW - Unclear if gg exposes focus state, needs codebase verification

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable patterns, no API changes expected)
