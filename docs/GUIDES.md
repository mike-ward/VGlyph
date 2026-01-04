# vglyph Guides

This document covers common use-cases and deep dives into specific features.

## Rich Text Markup

`vglyph` leverages [Pango Markup](https://docs.gtk.org/Pango/pango_markup.html)
to support rich styling within a single string.

To use markup, you **must** set `use_markup: true` in your `TextConfig`.

### Basics

Markup uses XML-like tags. Tags must be properly closed/nested, or the layout
engine will return an error.

```okfmt
config := vglyph.TextConfig{
    font_name: 'Sans 16',
    use_markup: true
}

// Bold and Italic
app.ts.draw_text(10, 10, '<b>Bold</b> and <i>Italic</i>', config)!
```

### The `<span>` Tag

The `<span>` tag is the most powerful tool. It allows you to set specific
attributes for a range of text.

```okfmt
// Color and size
text := '<span foreground="blue" size="x-large">Blue Title</span>'

// Font weight and variant
text2 := '<span weight="bold" variant="small-caps">Small Caps Header</span>'

// Rise (Superscript-like effect)
text3 := '10<span size="small" rise="10000">th</span>'
```

### Full Attribute List

| Attribute | Description | Examples |
| :--- | :--- | :--- |
| `foreground` | Text color | `"#FF0000"`, `"blue"` |
| `background` | Background color | `"yellow"`, `"#333"` |
| `size` | Font size | `"small"`, `"x-large"`, `"12pt"` |
| `weight` | Font weight | `"light"`, `"bold"`, `"400"` |
| `rise` | Vertical align shift | `"5000"` (positive = up) |
| `underline` | Style of underline | `"single"`, `"double"`, `"none"` |
| `strikethrough` | Strikethrough | `"true"` |

---

## Font Management

### Loading Local Fonts

You can load `.ttf` or `.otf` files at runtime. This is critical for bundling
fonts with your game or app.

1. **Load the file**:
   ```okfmt
   // Call this once during init
   success := app.ts.add_font_file('assets/fonts/Inter-Regular.ttf')
   ```

2. **Reference by Name**:
   You do not use the filename to use the font. You must use the **Family Name**
   embedded in the font file.

   *Tip*: If you don't know the family name, open the font file in your OS font
   viewer.

   ```okfmt
   cfg := vglyph.TextConfig{
       font_name: 'Inter 14' // "Inter" is the family name
   }
   ```

### Icon Fonts

Icon fonts (like FontAwesome or Feather) work just like regular fonts.

1. Load the font: `app.ts.add_font_file('assets/feather.ttf')`
2. Use the Unicode Private Use Area (PUA) codepoints to display icons.

```okfmt
// Use \u escape sequence for the icon codepoint
icon_code := '\uF120'

app.ts.draw_text(x, y, icon_code, vglyph.TextConfig{
    font_name: 'Feather 24'
})
```

---

## Performance Best Practices

### 1. Cache Your Layouts (Automatic)

Text shaping (calculating word wrap and glyph positions) is CPU intensive.

- **`TextSystem` users**: Caching is automatic. `draw_text` creates a hash of
  your text + config. If you draw the same string next frame, it hits the cache.
- **Dynamic Text**: If you have a counter that changes every frame (e.g.,
  `FPS: 60` -> `FPS: 61`), `TextSystem` will re-layout every time. This is
  usually fast enough for short strings, but avoid doing it for large paragraphs
  of changing text.

### 2. The `commit()` Cycle

GPU textures should not be updated multiple times per frame. `vglyph` queues
glyph uploads and performs them all at once when you call `commit()`.

**Rule**: Call `app.ts.commit()` exactly **once** at the end of your render
loop.

### 3. Glyph Atlas Size

The default atlas starts at 1024x1024 and **automatically resizes** if it fills
up. You generally do not need to manage this manually.

Exceptions where you might need `new_text_system_atlas_size`:
- **Massive Glyphs**: If a single glyph is larger than the default atlas size
  (e.g., > 1024px wide), you must initialize with a larger size.

