# IME Appendix

This document provides detailed documentation for VGlyph's Input Method Editor (IME) support,
including dead key composition tables and future CJK IME plans.

See [EDITING.md](./EDITING.md) for API usage examples.

## Table of Contents

- [Current State](#current-state)
- [Dead Key Composition](#dead-key-composition)
- [IME Composition State](#ime-composition-state)
- [Future Work: CJK IME](#future-work-cjk-ime)

---

## Current State

### What Works

- **Dead key composition** for accented Latin characters (grave, acute, circumflex, tilde, umlaut,
  cedilla)
- **macOS NSTextInputClient bridge** implemented via NSView category
- **Callback registration** for V integration: `ime_register_callbacks`
- **Composition bounds** for candidate window positioning

### What Doesn't Work Yet

- **CJK IME composition** (Japanese, Chinese, Korean input methods)
- Root cause: NSView category doesn't connect to sokol's MTKView
- The infrastructure exists (CompositionState, ClauseRects) but can't receive IME events

---

## Dead Key Composition

Dead keys are accent starter characters that combine with a following base character.

### Supported Dead Keys

| Dead Key | Name       | Example |
|:---------|:-----------|:--------|
| `` ` ``  | Grave      | ` + e = e |
| `'`      | Acute      | ' + e = e |
| `^`      | Circumflex | ^ + e = e |
| `~`      | Tilde      | ~ + n = n |
| `"` / `:` | Diaeresis (Umlaut) | " + o = o |
| `,`      | Cedilla    | , + c = c |

### Combination Tables

**Grave accent (`):**

| Base | Result | Unicode |
|:-----|:-------|:--------|
| a    | a      | U+00E0  |
| e    | e      | U+00E8  |
| i    | i      | U+00EC  |
| o    | o      | U+00F2  |
| u    | u      | U+00F9  |
| A-U  | A-U (uppercase) | U+00C0-U+00D9 |

**Acute accent ('):**

| Base | Result | Unicode |
|:-----|:-------|:--------|
| a    | a      | U+00E1  |
| e    | e      | U+00E9  |
| i    | i      | U+00ED  |
| o    | o      | U+00F3  |
| u    | u      | U+00FA  |
| A-U  | A-U (uppercase) | U+00C1-U+00DA |

**Circumflex (^):**

| Base | Result | Unicode |
|:-----|:-------|:--------|
| a    | a      | U+00E2  |
| e    | e      | U+00EA  |
| i    | i      | U+00EE  |
| o    | o      | U+00F4  |
| u    | u      | U+00FB  |
| A-U  | A-U (uppercase) | U+00C2-U+00DB |

**Tilde (~):**

| Base | Result | Unicode |
|:-----|:-------|:--------|
| a    | a      | U+00E3  |
| n    | n      | U+00F1  |
| o    | o      | U+00F5  |
| A,N,O | A,N,O (uppercase) | U+00C3,U+00D1,U+00D5 |

**Diaeresis/Umlaut (" or :):**

| Base | Result | Unicode |
|:-----|:-------|:--------|
| a    | a      | U+00E4  |
| e    | e      | U+00EB  |
| i    | i      | U+00EF  |
| o    | o      | U+00F6  |
| u    | u      | U+00FC  |
| y    | y      | U+00FF  |
| A-U  | A-U (uppercase) | U+00C4-U+00DC |

**Cedilla (,):**

| Base | Result | Unicode |
|:-----|:-------|:--------|
| c    | c      | U+00E7  |
| C    | C      | U+00C7  |

### Invalid Combinations

When a dead key is followed by a character that cannot be combined:
- Both characters are inserted separately
- Example: ` + x produces `x (grave followed by x)

### API Usage

```v ignore
// Check if character is a dead key
if vglyph.is_dead_key(ch) {
    dead_key.start_dead_key(ch, cursor)
    return
}

// Try to combine with pending dead key
if dead_key.has_pending() {
    combined, was_combined := dead_key.try_combine(ch)
    // combined: "e" if was_combined, or "`x" if not
    insert_text(combined)
    return
}
```

---

## IME Composition State

For input methods with preedit text (intermediate text before final commit).

### CompositionPhase

```v ignore
pub enum CompositionPhase {
    none      // No active composition
    composing // Preedit text being edited
}
```

### Lifecycle

1. **Start** - User begins composition (e.g., types first hiragana)
2. **set_marked_text** - IME updates preedit with converted text
3. **Commit or Cancel** - User confirms or cancels

### Rendering Composition

Preedit text should be:
- Inserted visually at cursor position
- Underlined to indicate uncommitted state
- Different underline thickness for selected clause (thick) vs others (thin)

```v ignore
// Get rectangles for underline rendering
clause_rects := composition.get_clause_rects(layout)
for cr in clause_rects {
    thickness := match cr.style {
        .selected { f32(2) }  // Thick underline
        else { f32(1) }       // Thin underline
    }
    // Draw underline at bottom of each rect
}
```

### Clause Styles

| Style     | Meaning                        | Underline |
|:----------|:-------------------------------|:----------|
| `.raw`    | Unconverted input (hiragana)   | Thin      |
| `.converted` | Converted text (kanji)      | Thin      |
| `.selected` | Currently selected for conversion | Thick |

---

## Future Work: CJK IME

### Current Limitation

VGlyph's IME bridge uses an NSView category to add NSTextInputClient conformance. However, sokol
uses MTKView (Metal view) which doesn't inherit the category methods. The IME system queries the
MTKView directly, bypassing VGlyph's implementation.

### Potential Solutions

1. **Modify sokol** - Add NSTextInputClient conformance directly to sokol's MTKView subclass

2. **Overlay view** - Create transparent NSView overlay positioned over text area that receives
   IME events and forwards to VGlyph

3. **Custom MTKView subclass** - Fork sokol or use custom view class that inherits from both
   MTKView and conforms to NSTextInputClient

### Infrastructure Ready

The VGlyph code is prepared for CJK IME:

- `CompositionState` tracks multi-clause preedit with style info
- `Clause` struct stores segment boundaries and selection state
- `ClauseRects` provides geometry for multi-segment underline rendering
- `get_composition_bounds` returns bounds for candidate window positioning
- Coordinate conversion handles top-left to bottom-left for macOS

### Testing CJK IME

Once the bridge is fixed, test with:
1. Japanese (Hiragana -> Kanji conversion with clause selection)
2. Chinese Pinyin (tone marks, character selection)
3. Korean (Hangul composition, jamo -> syllable)

### Platform Notes

- **macOS** - NSTextInputClient protocol, firstRectForCharacterRange for candidate positioning
- **Linux** - IBus or Fcitx integration (not implemented)
- **Windows** - IMM32 or TSF (not implemented)

---

## See Also

- [EDITING.md](./EDITING.md) - Main editing API documentation
- [composition.v](../composition.v) - Implementation source
