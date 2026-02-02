# Technology Stack — Text Editing & IME

**Project:** VGlyph v1.3
**Focus:** Text editing capabilities and IME support
**Researched:** 2026-02-02
**Confidence:** HIGH

## Executive Summary

Text editing adds cursor positioning, selection, mutation, and IME on top of existing rendering.
No new C libraries — Pango provides all needed APIs. macOS IME via NSTextInputClient protocol.
V FFI handles Objective-C callbacks. Integration: existing hit testing foundation already built.

## Stack Additions Required

### None — Existing Stack Sufficient

**All needed APIs already available through existing dependencies:**
- Pango 1.0 (existing)
- macOS Cocoa/Foundation frameworks (existing via accessibility layer)
- Objective-C runtime (existing via accessibility/objc_helpers.h)

**Rationale:** Text editing is API extension, not new dependencies.

## API Details

### Pango APIs for Editing (Already Bound)

Most needed APIs already declared in `c_bindings.v`. Missing APIs listed below.

#### Already Available

| API | Purpose | File |
|-----|---------|------|
| `pango_layout_index_to_pos` | Cursor position → rect | c_bindings.v:530 |
| `pango_layout_set_text` | Text mutation | c_bindings.v:524 |
| `pango_layout_xy_to_index` | Mouse → text index | Needs binding |

#### Need to Add

| API | Signature | Purpose |
|-----|-----------|---------|
| `pango_layout_get_cursor_pos` | `void(PangoLayout*, int, PangoRectangle*, PangoRectangle*)` | Strong/weak cursor rects |
| `pango_layout_xy_to_index` | `bool(PangoLayout*, int, int, int*, int*)` | Screen coords → byte index |
| `pango_layout_move_cursor_visually` | `void(PangoLayout*, bool, int, int, int, int*, int*)` | Keyboard navigation |

**Add to c_bindings.v:**
```v
fn C.pango_layout_get_cursor_pos(&C.PangoLayout, int, &C.PangoRectangle, &C.PangoRectangle)
fn C.pango_layout_xy_to_index(&C.PangoLayout, int, int, &int, &int) bool
fn C.pango_layout_move_cursor_visually(&C.PangoLayout, bool, int, int, int, &int, &int)
```

### Pango Cursor APIs — Detailed Behavior

#### pango_layout_get_cursor_pos

Returns two cursor rects (strong/weak) as zero-width rectangles with run height.

**Strong cursor:** Insertion point for text matching layout base direction
**Weak cursor:** Insertion point for opposite-direction text (bidi)

**Parameters accept NULL** if only one cursor needed.

**Source:** [Pango.Layout.get_cursor_pos](https://docs.gtk.org/Pango/method.Layout.get_cursor_pos.html)

#### pango_layout_xy_to_index

Converts screen coordinates to byte index. Returns TRUE if coords inside layout, FALSE outside.

**Clamping behavior:**
- Y outside: snaps to nearest line
- X outside: snaps to line start/end

**Trailing output:** 0 for leading edge, N for trailing edge (grapheme position)

**Source:** [Pango.Layout.xy_to_index](https://docs.gtk.org/Pango/method.Layout.xy_to_index.html)

#### pango_layout_move_cursor_visually

Computes new cursor position from old position + direction (visual order).

**Key for:** Left/right arrow navigation respecting bidi text order

**Handles:**
- Bidirectional text jumps
- Grapheme boundaries (multi-char glyphs like emoji)
- Visual vs logical order differences

**Source:** [Pango.Layout.move_cursor_visually](https://docs.gtk.org/Pango/method.Layout.move_cursor_visually.html)

### macOS IME — NSTextInputClient Protocol

**Protocol:** `NSTextInputClient`
**Framework:** AppKit (Cocoa)
**Purpose:** IME composition window positioning and marked text handling

#### Required Methods

| Method | Purpose |
|--------|---------|
| `insertText:replacementRange:` | Insert committed text |
| `setMarkedText:selectedRange:replacementRange:` | Handle composition |
| `markedRange()` | Get marked text range |
| `selectedRange()` | Get current selection |
| `firstRectForCharacterRange:actualRange:` | Position IME candidate window |
| `unmarkText()` | Clear composition |
| `validAttributesForMarkedText()` | Supported attributes |
| `hasMarkedText()` | Check composition state |
| `attributedSubstringForProposedRange:actualRange:` | Text for IME |

**Source:** [NSTextInputClient](https://developer.apple.com/documentation/appkit/nstextinputclient)

#### Integration Strategy

**Reuse existing Objective-C bridge** from accessibility layer:
- `accessibility/objc_helpers.h` (C wrapper for objc_msgSend)
- `accessibility/objc_bindings_darwin.v` (V FFI declarations)
- Pattern: wrap NSTextInputClient methods as C functions callable from V

**Implementation approach:**
1. Create `text_input_objc_darwin.v` with NSTextInputClient wrapper
2. Add helper functions to `objc_helpers.h` for NSTextInputClient callbacks
3. V widget layer calls Objective-C bridge, bridge calls back to V

**Example existing pattern (from accessibility):**
```v
fn C.v_msgSend_void_id(self Id, op SEL, arg1 voidptr)
pub fn set_accessibility_label(elem Id, label string) {
    label_ns := ns_string(label)
    C.v_msgSend_void_id(elem, sel_register_name('setAccessibilityLabel:'), label_ns)
}
```

**New pattern for IME:**
```v
fn C.v_msgSend_nsrange(self Id, op SEL) C.NSRange
pub fn get_marked_range(input_context Id) NSRange {
    return C.v_msgSend_nsrange(input_context, sel_register_name('markedRange'))
}
```

### Text Mutation Strategy

**Pango has no incremental mutation API.** Must rebuild layout on every change.

**Process:**
1. Maintain text buffer in V (string)
2. On insert/delete: V string manipulation (`s[..pos] + new_text + s[pos..]`)
3. Call `pango_layout_set_text(layout, buffer.str, buffer.len)`
4. Invalidate layout cache (create new cache entry)

**Optimization:** Layout cache handles repeated renders of same text.
**Tradeoff:** Simple API, slightly higher latency on edits vs incremental update.

**Source:** [Pango.Layout.set_text](https://docs.gtk.org/Pango/method.Layout.set_text.html)

## Integration with Existing Stack

### Hit Testing Foundation (Existing)

**Already implemented in `layout_query.v`:**

| Function | Status | Use |
|----------|--------|-----|
| `hit_test(x, y)` | Exists | Mouse → byte index |
| `get_char_rect(index)` | Exists | Index → rect |
| `get_closest_offset(x, y)` | Exists | Snap to nearest char |
| `get_selection_rects(start, end)` | Exists | Selection highlighting |

**These are foundational for editing. No changes needed.**

### Cursor Position API (New)

**Add to `layout_query.v`:**
```v
pub fn (l Layout) get_cursor_pos(index int) ?(gg.Rect, gg.Rect) {
    // Call pango_layout_get_cursor_pos
    // Convert PangoRectangle to gg.Rect
    // Return (strong_cursor, weak_cursor)
}

pub fn (l Layout) move_cursor(index int, direction int, visual bool) int {
    // Call pango_layout_move_cursor_visually
    // Return new index
}
```

### Text Mutation API (New)

**Add to `api.v` (TextSystem):**
```v
pub fn (mut ts TextSystem) mutate_text(original string, pos int, insert string, delete_len int) !Layout {
    // 1. String manipulation
    mut buf := original[..pos] + insert
    if pos + delete_len < original.len {
        buf += original[pos + delete_len..]
    }

    // 2. Rebuild layout
    return ts.ctx.layout_text(buf, cfg)
}
```

**Alternative:** Widget layer handles mutation, VGlyph just re-layouts.

### IME Integration (New Module)

**Create `text_input_darwin.v` (parallel to accessibility layer):**

```v
module vglyph

@[if darwin]
struct TextInputContext {
mut:
    input_client Id
    marked_range NSRange
}

pub fn (mut ctx TextInputContext) set_marked_text(text string, sel_range NSRange) {
    // Bridge to NSTextInputClient
}

pub fn (ctx TextInputContext) get_first_rect_for_range(range NSRange) gg.Rect {
    // Query layout for character rects
    // Convert to screen coords
    // Return for IME candidate window positioning
}
```

**Platform abstraction:** Stub implementation for non-macOS (no-op).

## V Language FFI Considerations

### C Function Binding Pattern

V requires explicit C function declarations. Pattern already established:

```v
// In c_bindings.v
fn C.pango_layout_get_cursor_pos(&C.PangoLayout, int, &C.PangoRectangle, &C.PangoRectangle)

// In V code
pub fn (l Layout) get_cursor_pos(index int) ?(gg.Rect, gg.Rect) {
    mut strong := C.PangoRectangle{}
    mut weak := C.PangoRectangle{}
    unsafe {
        C.pango_layout_get_cursor_pos(l.handle, index, &strong, &weak)
    }
    return (pango_rect_to_gg(strong), pango_rect_to_gg(weak))
}
```

**Source:** [V Calling C](https://docs.vlang.io/v-and-c.html)

### Objective-C Bridge Pattern

Already working in accessibility layer. Pattern:

1. **C header** (`objc_helpers.h`): Inline wrapper for `objc_msgSend` with typed signatures
2. **V FFI** (`objc_bindings_darwin.v`): Declare C wrappers as `fn C.v_msgSend_XXX(...)`
3. **V wrapper** (`backend_darwin.v`): V functions call C wrappers

**No new infrastructure needed.** Extend existing pattern for NSTextInputClient.

### Struct Handling

Pango structs already defined in `c_bindings.v`. NSRange/NSRect needed:

```v
@[typedef]
pub struct C.NSRange {
pub:
    location int
    length int
}
```

**Add to `objc_bindings_darwin.v` alongside existing NSRect.**

### Callback Handling

V supports callbacks via function types:

```v
type TextInputCallback = fn (mut ctx TextInputContext, text string)

// Register with Objective-C runtime via class_addMethod
```

**Precedent:** V channels and closures handle async C callbacks.

**Limitation:** Global function pointers only (no closures across FFI boundary).
**Mitigation:** Single global input context, dispatch to active widget.

## What NOT to Add

### ❌ ICU (International Components for Unicode)

**Why skip:** Pango already handles Unicode normalization, grapheme breaking, bidi.
**Redundant with:** HarfBuzz (via Pango), FriBidi (via Pango).
**Cost:** 25+ MB dependency for capabilities already present.

### ❌ Platform-Specific Text APIs

**Why skip:**
- Windows Text Services Framework (TSF): Windows IME
- Linux IBus/Fcitx: Linux IME

**Rationale:** v1.3 scope is macOS primary. Other platforms later.
**Decision:** Stub implementations for non-Darwin builds.

### ❌ Text Input Method Engines

**Why skip:** VGlyph consumes IME output, doesn't implement IME.
**Responsibility:** OS provides IME (Japanese, Chinese input methods).
**VGlyph role:** Display composition, position candidate window, commit text.

### ❌ Undo/Redo Infrastructure

**Why skip:** Widget layer concern, not text rendering.
**Rationale:** VGlyph provides primitives (cursor pos, mutation). v-gui handles state.
**Decision:** Document undo/redo patterns in v-gui integration examples.

### ❌ Text Editing Commands (Copy/Paste/Select All)

**Why skip:** v-gui event handlers manage clipboard, commands.
**VGlyph provides:** Selection rects, hit testing, cursor geometry.
**v-gui provides:** Keyboard events, clipboard access, command dispatch.

## API Surface Summary

### Core Editing Primitives (VGlyph)

| API | Input | Output | Layer |
|-----|-------|--------|-------|
| `get_cursor_pos(index)` | Byte index | Strong/weak cursor rects | layout_query.v |
| `move_cursor(index, dir)` | Index, direction | New index | layout_query.v |
| `get_char_rect(index)` | Byte index | Character rect | layout_query.v (exists) |
| `get_selection_rects(start, end)` | Range | Highlight rects | layout_query.v (exists) |
| `hit_test(x, y)` | Coords | Byte index | layout_query.v (exists) |
| `layout_text(text, cfg)` | Text, config | Layout | api.v (exists) |

### IME Support (VGlyph — macOS only)

| API | Purpose | Layer |
|-----|---------|-------|
| `new_text_input_context()` | Create IME context | text_input_darwin.v |
| `set_marked_text(text, range)` | Composition preview | text_input_darwin.v |
| `commit_text(text)` | Finalize input | text_input_darwin.v |
| `get_marked_range()` | Query composition | text_input_darwin.v |
| `first_rect_for_range(range)` | Candidate window pos | text_input_darwin.v |

### Widget Integration (v-gui)

| Component | Responsibility |
|-----------|---------------|
| TextField/TextArea | State management, event handling, focus |
| VGlyph | Cursor geometry, selection rects, rendering |
| v-gui event loop | Keyboard events, mouse events, blink timer |

## Build Configuration

### No New Dependencies

```bash
# v1.2 build (unchanged)
v -cc clang -cflags "`pkg-config --cflags pango pangoft2`" \
  -ldflags "`pkg-config --libs pango pangoft2`" .

# macOS adds existing frameworks (no change)
-framework Foundation -framework Cocoa
```

### Conditional Compilation

```v
// Existing pattern from accessibility layer
@[if darwin]
struct TextInputContext { ... }

@[if !darwin]
struct TextInputContext { } // Stub
```

### No Profile Flag Changes

Editing features are unconditional. No `-d editing` flag needed.

## Testing Strategy

### Unit Tests (Pango APIs)

```v
// _cursor_test.v
fn test_cursor_position() {
    mut ts := vglyph.new_text_system(mut ctx)!
    layout := ts.layout_text('Hello', cfg)!

    pos := layout.get_cursor_pos(0) or { panic(err) }
    assert pos.0.width == 0 // Zero-width cursor
}
```

### Integration Tests (IME)

**Manual testing required** for IME on macOS:
1. Enable Japanese input method
2. Type "nihon" → see composition
3. Press Space → see candidates
4. Press Enter → commit

**Automated:** Difficult (requires OS input method simulation).

### Demo (`editor_demo.v` extension)

**Extend existing demo:**
- Add cursor rendering
- Add selection highlighting
- Add keyboard navigation
- Add IME composition preview

## Version Planning

### v1.3.0 Scope

**Minimum for release:**
- Cursor positioning API (`get_cursor_pos`, `move_cursor`)
- Text mutation (string ops + re-layout)
- macOS IME via NSTextInputClient
- v-gui TextField widget (basic)
- Working demo

**Deferred to v1.3.1+:**
- Multi-line editing improvements (TextArea)
- Linux/Windows IME (IBus, TSF)
- Advanced keyboard navigation (word jump, etc.)

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Objective-C callback complexity | Medium | Reuse accessibility pattern |
| IME candidate window positioning | Medium | Test early with CJK input |
| V string mutation performance | Low | Layout cache handles repeated text |
| Platform-specific IME bugs | High | Limit v1.3 to macOS, stub others |

## Open Questions

None. All needed APIs identified and verified.

## Sources

**Pango Documentation (HIGH confidence):**
- [pango_layout_get_cursor_pos](https://docs.gtk.org/Pango/method.Layout.get_cursor_pos.html)
- [pango_layout_xy_to_index](https://docs.gtk.org/Pango/method.Layout.xy_to_index.html)
- [pango_layout_move_cursor_visually](https://docs.gtk.org/Pango/method.Layout.move_cursor_visually.html)
- [pango_layout_set_text](https://docs.gtk.org/Pango/method.Layout.set_text.html)

**Apple Documentation (HIGH confidence):**
- [NSTextInputClient Protocol](https://developer.apple.com/documentation/appkit/nstextinputclient)

**V Language (HIGH confidence):**
- [V Calling C](https://docs.vlang.io/v-and-c.html)

**v-gui Framework (MEDIUM confidence):**
- [vlang/gui Repository](https://github.com/vlang/gui)
- [vlang/ui Repository](https://github.com/vlang/ui)

**Implementation Examples (MEDIUM confidence):**
- [NSTextInputClient Example](https://github.com/jessegrosjean/NSTextInputClient)
- Mozilla Firefox NSTextInputClient implementation

---

*Research complete. Stack sufficient. No new dependencies required.*
