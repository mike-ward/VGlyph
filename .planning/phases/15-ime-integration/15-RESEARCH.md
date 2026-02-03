# Phase 15: IME Integration - Research

**Researched:** 2026-02-03
**Domain:** macOS Input Method Editor (IME) integration for CJK and accented character input
**Confidence:** MEDIUM

## Summary

IME integration enables users to input CJK (Chinese, Japanese, Korean) and accented characters via the
system Input Method Editor. On macOS, this requires implementing the `NSTextInputClient` protocol, which
the text view uses to communicate with the text input management system. The protocol handles marked
text (preedit), composition state, cursor positioning for candidate windows, and dead key sequences.

VGlyph operates within v-gui's gg framework, which uses Sokol as its backend. Sokol explicitly does not
implement IME support, recommending applications implement it themselves using native window handles.
This means VGlyph/v-gui needs to either: (a) add NSTextInputClient protocol implementation to gg's
Cocoa backend, or (b) provide hooks for applications to implement IME separately. Option (a) is the
cleaner approach for a text rendering library.

Key insight: VGlyph already has the cursor geometry APIs needed for IME candidate window positioning
(`get_cursor_pos`, `get_selection_rects`). The main work is: (1) creating an IME composition state
manager, (2) implementing preedit text display with underlines, (3) bridging to macOS text input system
via native code, and (4) handling coordinate transformation from layout-relative to screen coordinates.

**Primary recommendation:** Implement composition state in VGlyph, add native macOS bridge for
NSTextInputClient protocol, use existing cursor geometry for candidate window positioning.

## Standard Stack

### Core macOS APIs (Native Integration Required)
| API | Purpose | Why Standard |
|-----|---------|--------------|
| `NSTextInputClient` protocol | Text input system communication | Required for macOS IME |
| `NSTextInputContext` | Input context management | Manages active input sources |
| `convertRectToScreen:` | Coordinate conversion | Required for candidate window |

### VGlyph APIs to Leverage (Existing)
| API | Location | Purpose | Status |
|-----|----------|---------|--------|
| `Layout.get_cursor_pos` | layout_query.v | Cursor geometry | Working |
| `Layout.get_selection_rects` | layout_query.v | Range rectangles | Working |
| `Layout.get_char_rect` | layout_query.v | Character bounds | Working |
| `TextStyle.underline` | layout_types.v | Underline decoration | Working |
| `insert_text` | layout_mutation.v | Text insertion | Working |
| `insert_replacing_selection` | layout_mutation.v | Replace range | Working |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Native Obj-C bridge | Pure V bindings | Obj-C simpler for protocol conformance |
| VGlyph owns composition | App owns composition | VGlyph already has rendering/layout |
| Custom underline for preedit | Reuse TextStyle.underline | Custom allows thickness variants |

**Installation:** No additional libraries - uses macOS system frameworks (AppKit).

## Architecture Patterns

### Recommended State Model
```
IME Integration Components:

1. CompositionState (VGlyph)
   - preedit_text: string       # Current composition string
   - preedit_start: int         # Byte offset in document
   - cursor_in_preedit: int     # Cursor within preedit (for navigation)
   - clauses: []Clause          # Segment info for multi-clause IME
   - is_composing: bool         # Active composition flag

2. IMEBridge (Native Obj-C)
   - Implements NSTextInputClient protocol
   - Forwards events to VGlyph composition state
   - Queries VGlyph for cursor geometry

3. DeadKeyState (VGlyph)
   - pending_char: rune         # Dead key waiting for combination
   - pending_pos: int           # Position where dead key was typed
```

### Pattern 1: Composition State Machine
**What:** Track IME composition lifecycle
**When to use:** All IME interactions
**Example:**
```v
// Source: Firefox IME handling architecture

pub enum CompositionPhase {
    none        // No active composition
    composing   // Preedit text being edited
    committing  // About to commit
}

pub struct CompositionState {
pub mut:
    phase          CompositionPhase
    preedit_text   string
    preedit_start  int           // Byte offset in document where preedit inserted
    cursor_offset  int           // Cursor position within preedit (0 = start)
    clauses        []Clause      // For multi-segment CJK input
    selected_clause int          // Currently selected clause index
}

pub struct Clause {
pub:
    start  int   // Offset within preedit_text
    length int
    style  ClauseStyle
}

pub enum ClauseStyle {
    raw       // Unconverted input (thin underline)
    converted // Converted text (thin underline)
    selected  // Currently selected for conversion (thick underline)
}

// Start composition at cursor position
pub fn (mut cs CompositionState) start(cursor_pos int) {
    cs.phase = .composing
    cs.preedit_start = cursor_pos
    cs.preedit_text = ''
    cs.cursor_offset = 0
    cs.clauses.clear()
}

// Update preedit text (called by IME)
pub fn (mut cs CompositionState) set_marked_text(text string, selected_range Range) {
    cs.preedit_text = text
    cs.cursor_offset = selected_range.location
    // Update clauses based on IME attributes...
}

// Commit preedit as final text
pub fn (mut cs CompositionState) commit() string {
    result := cs.preedit_text
    cs.phase = .none
    cs.preedit_text = ''
    cs.cursor_offset = 0
    cs.clauses.clear()
    return result
}

// Cancel composition, discard preedit
pub fn (mut cs CompositionState) cancel() {
    cs.phase = .none
    cs.preedit_text = ''
    cs.cursor_offset = 0
    cs.clauses.clear()
}
```

### Pattern 2: NSTextInputClient Protocol Implementation
**What:** Native bridge to macOS text input system
**When to use:** Required for IME on macOS
**Example (Objective-C concept):**
```objc
// Source: Apple NSTextInputClient documentation, GLFW implementation

// Key methods to implement:

// Called when IME wants to insert final text
- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    NSString *text = [string isKindOfClass:[NSAttributedString class]]
        ? [(NSAttributedString*)string string] : string;
    // Forward to VGlyph: composition.commit() then insert_text()
    vglyph_ime_insert_text([text UTF8String], replacementRange);
}

// Called when IME updates composition/preedit
- (void)setMarkedText:(id)string
        selectedRange:(NSRange)selectedRange
     replacementRange:(NSRange)replacementRange {
    NSString *text = [string isKindOfClass:[NSAttributedString class]]
        ? [(NSAttributedString*)string string] : string;
    // Forward to VGlyph: composition.set_marked_text()
    vglyph_ime_set_marked_text([text UTF8String], selectedRange, replacementRange);
}

// Called when composition should be committed as-is
- (void)unmarkText {
    vglyph_ime_commit();
}

// Return range of marked text (preedit)
- (NSRange)markedRange {
    if (!vglyph_ime_has_marked_text())
        return NSMakeRange(NSNotFound, 0);
    return NSMakeRange(vglyph_ime_marked_start(), vglyph_ime_marked_length());
}

// Return current selection range
- (NSRange)selectedRange {
    int start = vglyph_ime_selection_start();
    int length = vglyph_ime_selection_length();
    return NSMakeRange(start, length);
}

// Return whether composition is active
- (BOOL)hasMarkedText {
    return vglyph_ime_has_marked_text();
}

// Return rectangle for IME candidate window positioning
// MUST return screen coordinates
- (NSRect)firstRectForCharacterRange:(NSRange)range
                         actualRange:(NSRangePointer)actualRange {
    // Get cursor rect from VGlyph (layout-relative)
    float x, y, width, height;
    vglyph_ime_get_composition_rect(&x, &y, &width, &height);

    // Convert to window coordinates
    NSRect viewRect = NSMakeRect(x + offsetX, y + offsetY, width, height);
    NSRect windowRect = [self convertRect:viewRect toView:nil];

    // Convert to screen coordinates (required by IME)
    NSRect screenRect = [[self window] convertRectToScreen:windowRect];

    if (actualRange)
        *actualRange = range;

    return screenRect;
}
```

### Pattern 3: Preedit Display with Clause Underlines
**What:** Render composition text with underline styling
**When to use:** During active IME composition
**Example:**
```v
// Source: User decisions from CONTEXT.md

// Draw preedit text with underline styling
pub fn draw_preedit(mut ctx Context, cs CompositionState, base_text string,
                    cfg TextConfig, offset_x f32, offset_y f32) {
    if !cs.is_composing() { return }

    // Build display text with preedit inserted
    display_text := base_text[..cs.preedit_start] + cs.preedit_text +
                    base_text[cs.preedit_start..]

    // Get preedit bounds for underline
    preedit_end := cs.preedit_start + cs.preedit_text.len

    // Draw with clause-specific underlines
    for clause in cs.clauses {
        clause_start := cs.preedit_start + clause.start
        clause_end := clause_start + clause.length

        // Get rects for this clause
        rects := layout.get_selection_rects(clause_start, clause_end)

        // Draw underline (thick for selected, thin for others)
        thickness := if clause.style == .selected { 2.0 } else { 1.0 }
        for rect in rects {
            ctx.gg_ctx.draw_rect_filled(
                offset_x + rect.x,
                offset_y + rect.y + rect.height - thickness,
                rect.width,
                thickness,
                cfg.style.color  // Same color as text per user decision
            )
        }
    }

    // Draw cursor inside preedit if navigating
    cursor_byte := cs.preedit_start + cs.cursor_offset
    if pos := layout.get_cursor_pos(cursor_byte) {
        // Render cursor (visible per user decision)
        ctx.gg_ctx.draw_rect_filled(offset_x + pos.x, offset_y + pos.y,
                                    2, pos.height, cursor_color)
    }
}
```

### Pattern 4: Dead Key Handling
**What:** Support accent composition (e.g., ` + e = e)
**When to use:** European language input without full IME
**Example:**
```v
// Source: User decisions from CONTEXT.md

pub struct DeadKeyState {
pub mut:
    pending      ?rune    // Dead key waiting for combination
    pending_pos  int      // Position in text where typed
}

// Handle key press, return true if handled as dead key
pub fn (mut dks DeadKeyState) handle_key(key_char rune, cursor int) ?string {
    // Check if this is a dead key (accent starter)
    if is_dead_key(key_char) {
        if dks.pending != none {
            // Two dead keys in a row: insert first as-is, start new
            result := rune_to_string(dks.pending or { return none })
            dks.pending = key_char
            dks.pending_pos = cursor
            return result
        }
        dks.pending = key_char
        dks.pending_pos = cursor
        return none  // Swallow key, show placeholder
    }

    // Try to combine with pending dead key
    if dead := dks.pending {
        combined := combine_dead_key(dead, key_char)
        dks.pending = none

        if combined != none {
            // Successful combination (e.g., ` + e = e)
            return rune_to_string(combined or { return none })
        } else {
            // Invalid combination (e.g., ` + x): insert both separately
            return rune_to_string(dead) + rune_to_string(key_char)
        }
    }

    return none  // Not a dead key sequence
}

fn is_dead_key(r rune) bool {
    // Common dead keys for accents
    return r in [`\``, `'`, `^`, `~`, `"`, `:`, `,`]
}

fn combine_dead_key(dead rune, base rune) ?rune {
    // Lookup table for dead key combinations
    // Examples: ` + e = e, ' + e = e, ^ + a = a
    match dead {
        `\`` {
            match base {
                `a` { return `a` }
                `e` { return `e` }
                `i` { return `i` }
                `o` { return `o` }
                `u` { return `u` }
                `A` { return `A` }
                `E` { return `E` }
                `I` { return `I` }
                `O` { return `O` }
                `U` { return `U` }
                else { return none }
            }
        }
        // ... other dead keys
        else { return none }
    }
}

// Display: show dead key as placeholder with underline
pub fn draw_dead_key_placeholder(dks DeadKeyState, layout Layout, cfg TextConfig,
                                  offset_x f32, offset_y f32) {
    if dead := dks.pending {
        if pos := layout.get_cursor_pos(dks.pending_pos) {
            // Draw dead key character as placeholder (same styling as preedit)
            // Single underline per user decision
            placeholder := rune_to_string(dead)
            // ... render placeholder with underline
        }
    }
}
```

### Pattern 5: Coordinate Transformation for Candidate Window
**What:** Convert layout-relative coords to screen coords
**When to use:** `firstRectForCharacterRange` implementation
**Example:**
```v
// Source: Apple documentation, verified across implementations

// VGlyph provides composition bounds in layout-relative coordinates
pub fn (cs CompositionState) get_composition_bounds(layout Layout) ?gg.Rect {
    if !cs.is_composing() { return none }

    preedit_end := cs.preedit_start + cs.preedit_text.len
    rects := layout.get_selection_rects(cs.preedit_start, preedit_end)

    if rects.len == 0 { return none }

    // Return bounding rect of entire composition (per user decision)
    mut min_x := f32(1e9)
    mut min_y := f32(1e9)
    mut max_x := f32(-1e9)
    mut max_y := f32(-1e9)

    for r in rects {
        if r.x < min_x { min_x = r.x }
        if r.y < min_y { min_y = r.y }
        if r.x + r.width > max_x { max_x = r.x + r.width }
        if r.y + r.height > max_y { max_y = r.y + r.height }
    }

    return gg.Rect{
        x:      min_x
        y:      min_y
        width:  max_x - min_x
        height: max_y - min_y
    }
}

// Native code then transforms:
// 1. Add text view offset (where layout is rendered in view)
// 2. convertRect:toView:nil (view -> window coords)
// 3. convertRectToScreen: (window -> screen coords)
```

### Anti-Patterns to Avoid
- **Blocking during composition:** Never block the main thread waiting for IME
- **Modifying text during composition:** Only modify on commit, not during preedit updates
- **Screen coordinate confusion:** Always use convertRectToScreen for IME positioning
- **Ignoring replacementRange:** Some IMEs use this for nested composition
- **Direct character handling during composition:** Let NSTextInputClient handle all input

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dead key combinations | Manual lookup tables | macOS interpretKeyEvents: | System handles all keyboard layouts |
| Text input dispatching | Manual key event handling | NSTextInputClient | Required for proper IME integration |
| Candidate window position | Manual screen positioning | Let macOS position | Edge collision handled by system |
| Unicode composition | Manual combining | NSTextInputClient setMarkedText | System handles all scripts |

**Key insight:** macOS's text input system is designed to handle the complexity of international
input. Fighting it leads to bugs with specific keyboards or IMEs.

## Common Pitfalls

### Pitfall 1: Wrong Coordinate Space for Candidate Window
**What goes wrong:** Candidate window appears in wrong location (top-left, off-screen)
**Why it happens:** Returning view-relative coords instead of screen coords
**How to avoid:** Use `convertRect:toView:nil` then `convertRectToScreen:`
**Warning signs:** Candidate window at (0,0), follows window not text

### Pitfall 2: Modifying Text During Composition
**What goes wrong:** Corruption, IME state desync, partial commits
**Why it happens:** Treating preedit updates as text mutations
**How to avoid:** Preedit is overlay; only modify document on `insertText:` or `unmarkText`
**Warning signs:** Garbled text, duplicate characters, IME stops responding

### Pitfall 3: Incorrect markedRange Return
**What goes wrong:** IME can't track composition, breaks CJK input
**Why it happens:** Returning wrong range or forgetting NSNotFound for no composition
**How to avoid:** Return `{NSNotFound, 0}` when no marked text, correct range otherwise
**Warning signs:** Japanese IME shows no underline, Chinese pinyin doesn't accumulate

### Pitfall 4: Ignoring selectedRange Within Preedit
**What goes wrong:** Cursor position in composition not reflected
**Why it happens:** Only tracking preedit text, not cursor within it
**How to avoid:** Track `cursor_offset` within preedit, return in `selectedRange`
**Warning signs:** Arrow keys don't navigate within composition

### Pitfall 5: Focus Change During Composition
**What goes wrong:** Orphaned preedit text, IME state leaked
**Why it happens:** Not committing or canceling composition on focus loss
**How to avoid:** Per user decision: auto-commit on focus loss
**Warning signs:** Preedit text appears in new field, composition continues unexpectedly

### Pitfall 6: Click Outside Preedit Handling
**What goes wrong:** Preedit disappears without committing, cursor in wrong place
**Why it happens:** Not handling mouse events during composition
**How to avoid:** Per user decision: commit preedit, then move cursor to click
**Warning signs:** Text lost on click, cursor jumps unexpectedly

## Code Examples

### Integration with Editor Demo
```v
// Source: Extending editor_demo.v

@[heap]
struct EditorState {
mut:
    // Existing fields...
    text       string
    cursor_idx int
    anchor_idx int
    layout     vglyph.Layout

    // IME composition state (new)
    composition vglyph.CompositionState
    dead_key    vglyph.DeadKeyState
}

fn event(e &gg.Event, state_ptr voidptr) {
    mut state := unsafe { &EditorState(state_ptr) }

    match e.typ {
        .char {
            // During composition, let IME handle all input
            if state.composition.is_composing() {
                return  // IME bridge handles this
            }

            // Check for dead key
            if result := state.dead_key.handle_key(rune(e.char_code), state.cursor_idx) {
                // Dead key produced output
                apply_insert(mut state, result)
                return
            }

            // Normal character input...
        }
        .key_down {
            if state.composition.is_composing() {
                match e.key_code {
                    .escape {
                        // Per user decision: cancel composition
                        state.composition.cancel()
                        // Regenerate layout without preedit
                        state.layout = state.ts.layout_text(state.text, state.cfg) or { return }
                    }
                    .left, .right {
                        // Per user decision: navigate within preedit
                        // Let IME bridge handle via NSTextInputClient
                    }
                    else {}
                }
                return  // Don't process normal keys during composition
            }

            // Escape also cancels dead key
            if e.key_code == .escape && state.dead_key.pending != none {
                state.dead_key.pending = none
                return
            }
        }
        .mouse_down {
            if state.composition.is_composing() {
                // Per user decision: commit preedit, then move cursor
                commit_text := state.composition.commit()
                apply_insert(mut state, commit_text)
            }
            // Normal mouse handling...
        }
        .focus_out {
            if state.composition.is_composing() {
                // Per user decision: auto-commit on focus loss
                commit_text := state.composition.commit()
                apply_insert(mut state, commit_text)
            }
        }
        else {}
    }
}

fn frame(state_ptr voidptr) {
    mut state := unsafe { &EditorState(state_ptr) }

    state.gg_ctx.begin()

    // Draw selection backgrounds (existing)
    // ...

    // Draw text (existing)
    state.ts.draw_text(offset_x, offset_y, state.text, state.cfg) or {}

    // Draw preedit underlines if composing (new)
    if state.composition.is_composing() {
        draw_composition_underlines(state, offset_x, offset_y)
    }

    // Draw dead key placeholder if pending (new)
    if state.dead_key.pending != none {
        draw_dead_key_placeholder(state, offset_x, offset_y)
    }

    // Draw cursor (existing, but modified for composition)
    draw_cursor(state, offset_x, offset_y)

    state.gg_ctx.end()
}

fn draw_composition_underlines(state &EditorState, offset_x f32, offset_y f32) {
    // Draw underlines for each clause
    for i, clause in state.composition.clauses {
        clause_start := state.composition.preedit_start + clause.start
        clause_end := clause_start + clause.length
        rects := state.layout.get_selection_rects(clause_start, clause_end)

        // Thick underline for selected clause, thin for others
        thickness := if i == state.composition.selected_clause { 2.0 } else { 1.0 }

        for rect in rects {
            state.gg_ctx.draw_rect_filled(
                offset_x + rect.x,
                offset_y + rect.y + rect.height - thickness,
                rect.width,
                thickness,
                state.cfg.style.color
            )
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSTextInput protocol | NSTextInputClient | macOS 10.5 | Required for modern IME |
| Application renders candidate window | System renders | Always | Consistent UX |
| Manual dead key tables | interpretKeyEvents: | Always | Handles all keyboard layouts |
| Preedit in separate window | Inline preedit | Modern editors | Better UX |

**Deprecated/outdated:**
- `NSTextInput` protocol: Replaced by `NSTextInputClient` in 10.5
- Over-the-spot composition: Inline is standard now
- Manual candidate window positioning: Let system handle edge collision

## Open Questions

1. **Sokol/gg integration depth?**
   - What we know: Sokol doesn't implement IME, exposes `sapp_macos_get_window()`
   - What's unclear: How much native code needed in gg vs VGlyph
   - Recommendation: Minimal native bridge in gg, composition state in VGlyph

2. **Multi-clause IME attribute mapping?**
   - What we know: NSAttributedString carries clause styling info
   - What's unclear: Exact attribute keys for clause boundaries
   - Recommendation: Start with single underline style, enhance if needed

3. **Vertical text IME positioning?**
   - What we know: VGlyph supports vertical text orientation
   - What's unclear: How candidate window should position for vertical text
   - Recommendation: Defer to Phase 15 scope (horizontal primary)

## Sources

### Primary (HIGH confidence)
- [NSTextInputClient Protocol Reference](https://leopard-adc.pepas.com/documentation/Cocoa/Reference/NSTextInputClient_Protocol/Reference/Reference.html)
  Protocol methods and requirements
- [Firefox IME Handling Guide](https://firefox-source-docs.mozilla.org/editor/IMEHandlingGuide.html) -
  Architecture and state machine patterns
- [GLFW NSTextInputClient commit](https://fsunuc.physics.fsu.edu/git/gwm17/glfw/commit/3107c9548d7911d9424ab589fd2ab8ca8043a84a) -
  Implementation reference
- VGlyph layout_query.v - Existing cursor geometry APIs
- VGlyph layout_mutation.v - Existing text mutation APIs

### Secondary (MEDIUM confidence)
- [Sokol IME Issue #595](https://github.com/floooh/sokol/issues/595) - Hooks recommendation
- [GLFW IME PR #2117](https://github.com/glfw/glfw/pull/2117) - Preedit callback patterns
- [imgui IME Issue #5878](https://github.com/ocornut/imgui/issues/5878) - UI framework patterns
- [Mozilla Bug 875674](https://bugzilla.mozilla.org/show_bug.cgi?id=875674) - Implementation details

### Tertiary (LOW confidence)
- [jessegrosjean/NSTextInputClient](https://github.com/jessegrosjean/NSTextInputClient) - Reference
  implementation (author notes "probably not 100% right")
- WebSearch results for coordinate conversion - verified against Apple docs

## Metadata

**Confidence breakdown:**
- NSTextInputClient protocol: HIGH - Apple documentation, multiple implementations
- Composition state machine: HIGH - Firefox architecture well-documented
- Dead key handling: MEDIUM - User decisions clear, implementation details fuzzy
- gg/Sokol integration: LOW - No existing IME support, requires new native code

**Research date:** 2026-02-03
**Valid until:** 2026-03-03 (30 days - macOS APIs stable)
