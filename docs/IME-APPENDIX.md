# IME Appendix

This document provides detailed documentation for VGlyph's Input Method Editor (IME) support,
including dead key composition tables and future CJK IME plans.

See [EDITING.md](./EDITING.md) for API usage examples.

## Table of Contents

- [Current State](#current-state)
- [Dead Key Composition](#dead-key-composition)
- [IME Composition State](#ime-composition-state)
- [CJK IME via Overlay API](#cjk-ime-via-overlay-api-v18)

---

## Current State

### What Works

- **Dead key composition** for accented Latin characters (grave, acute,
  circumflex, tilde, umlaut, cedilla)
- **CJK IME composition** (Japanese, Chinese, Korean) via overlay API
- **NSWindow -> MTKView auto-discovery** for overlay creation
- **Per-overlay callbacks** with multi-field support
- **macOS NSTextInputClient bridge** via VGlyphIMEOverlayView
- **Composition bounds** for candidate window positioning

### What Doesn't Work Yet

- **Korean first-keypress** requires refocus (macOS system bug,
  QTBUG-136128, Apple FB17460926, Alacritty #6942)
- **Linux/Windows IME** (IBus, Fcitx, IMM32/TSF not implemented)

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

## CJK IME via Overlay API (v1.8+)

### Architecture

VGlyph uses overlay-based CJK IME on macOS:

- **VGlyphIMEOverlayView** - Transparent NSView implementing NSTextInputClient
- **Auto-discovery** - Discovers MTKView from NSWindow subview tree
- **Per-overlay callbacks** - Each overlay has independent callback set
- **Multi-field routing** - Single overlay supports multiple text fields via
  field IDs

### Testing CJK IME

CJK IME works on macOS (v1.8+). Test with:

1. Japanese (Hiragana -> Kanji conversion with clause selection)
2. Chinese Pinyin (tone marks, character selection)
3. Korean (Hangul composition, jamo -> syllable)

**Known issue:** Korean first-keypress requires refocus (macOS bug,
QTBUG-136128)

### Platform Notes

- **macOS** - NSTextInputClient protocol, firstRectForCharacterRange for candidate positioning
- **Linux** - IBus or Fcitx integration (not implemented)
- **Windows** - IMM32 or TSF (not implemented)

---

## See Also

- [EDITING.md](./EDITING.md) - Main editing API documentation
- [composition.v](../composition.v) - Implementation source
