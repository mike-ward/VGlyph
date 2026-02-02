# Phase 7: Vertical Coords - Research

**Researched:** 2026-02-02
**Domain:** Coordinate transforms for vertical text rendering
**Confidence:** HIGH

## Summary

Vertical text coordinate transforms are geometrically simple but error-prone due to:
1) Multiple coordinate spaces (Pango units, logical pixels, physical pixels, screen coords)
2) Orientation-dependent axis swapping (horizontal advance -> vertical advance)
3) Baseline semantics changing between upright and rotated text

Current vglyph implementation has vertical text transform logic scattered across layout.v
(lines 636-698) with incomplete inline docs. Comments explain WHAT transforms do but not WHY
they're needed or what coordinate space assumptions exist.

**Primary recommendation:** Extract separate `_upright()` / `_rotated()` functions for glyph
positioning, document coordinate system conventions once at file top, add inline transform
formulas at each call site.

## Standard Stack

### Core
No external libraries needed - this is pure coordinate math.

| Component | Purpose | Why Standard |
|-----------|---------|--------------|
| FreeType bearing/advance | Glyph metrics | Industry standard for font rasterization |
| Pango layout coordinates | Text flow positioning | Cross-platform text layout engine |
| V match statement | Orientation enum dispatch | Language builtin for exhaustive checking |

### V Language Enum Exhaustiveness

V compiler enforces exhaustive matching via compilation error when match statement doesn't cover
all enum variants. User decision: use match expressions for orientation dispatch to get compiler
verification that all cases handled.

**Current vglyph pattern:**
```v
if cfg.orientation == .vertical {
    // vertical path
}
// horizontal path (implicit else)
```

**Exhaustive pattern:**
```v
match cfg.orientation {
    .horizontal { /* ... */ }
    .vertical { /* ... */ }
}
```

V compiler error if new enum variant added but not handled in match.

## Architecture Patterns

### Coordinate System Documentation Pattern

**Standard approach:** Document coordinate system conventions ONCE at file top, reference in
individual transforms.

```v
// Coordinate Systems (vglyph conventions):
// - Pango units: 1/1024 of a point (PANGO_SCALE constant)
// - Logical pixels: 1pt = 1px (scale_factor accounts for DPI)
// - Physical pixels: logical * scale_factor (for rasterization)
// - Screen Y: Down is positive (standard graphics convention)
// - Baseline Y: Up is positive (FreeType/typography convention)
```

Source: Project existing patterns in layout.v lines 312-313, 578-579

### Transform Documentation Pattern (v1.1 pattern)

Document inline at call sites with:
1. Formula (math notation)
2. Why needed (coordinate space rationale)
3. ASCII diagram for complex transforms (optional)

**Example from Phase 6 FreeType docs:**
```v
// State: outline loaded (NO_BITMAP flag used, no FT_LOAD_RENDER)
// Requires: glyph.outline valid with n_points > 0
// Produces: outline shifted by subpixel amount
```

**Pattern for coordinate transforms:**
```v
// Transform: screen_y = baseline_y - bearing_y
// Why: FreeType bearing_y is upward from baseline, screen Y is downward
draw_y := (cy - f32(cg.top)) * scale_inv
```

Source: .planning/phases/06-freetype-state/06-01-PLAN.md lines 59-87

### Separate Functions for Upright vs Rotated

**Pattern:** Split complex orientation-dependent logic into dedicated functions with descriptive
suffixes.

```v
fn position_glyph_upright(cfg GlyphConfig) GlyphPosition { }
fn position_glyph_rotated(cfg GlyphConfig) GlyphPosition { }

// At call site:
pos := match cfg.orientation {
    .horizontal { position_glyph_upright(cfg) }
    .vertical { position_glyph_rotated(cfg) }
}
```

**Rationale:** Eliminates inline conditional logic, makes transforms testable independently,
clearly documents dispatch criteria.

Current vglyph has orientation conditionals inline (layout.v:637-668, 689-698), mixing concerns.

### Common Transform Helper Pattern

Extract shared transform logic into named helper functions:

```v
fn pango_to_pixels(pango_val int, scale_factor f32) f32 {
    return f32(pango_val) / (f32(pango_scale) * scale_factor)
}

fn swap_advance(x_adv f64, y_adv f64) (f64, f64) {
    return 0.0, -x_adv  // horizontal becomes vertical (downward)
}
```

Reduces duplication, documents transform once with clear name.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Coordinate space tracking | Ad-hoc variable naming | Naming convention (var_space) | Easy to lose track of which space value is in |
| Axis swapping logic | Inline x/y reassignment | Dedicated swap function | Error-prone, hard to verify correctness |
| Orientation dispatch | Multiple if statements | Match expression | Compiler can't verify exhaustiveness with if |

**Key insight:** Coordinate transforms fail silently (wrong position, not crash). Systematic
naming and exhaustive checking prevent subtle bugs.

## Common Pitfalls

### Pitfall 1: Mixed Coordinate Spaces
**What goes wrong:** Variable holds value in one coordinate space, used as if in another space.
Example: using pango units directly as pixels.

**Why it happens:** Transform occurs far from usage site, type system doesn't track units.

**How to avoid:** Naming convention indicating coordinate space:
- `x_pango`, `y_pango` (Pango units)
- `x_logical`, `y_logical` (logical pixels)
- `x_phys`, `y_phys` (physical pixels)

**Warning signs:** Glyph positions wildly wrong (1000x too large or small), rendering offscreen.

Source: Current vglyph code inconsistent (line 584 `run_x` unclear which space)

### Pitfall 2: Baseline Direction Confusion
**What goes wrong:** Y coordinate treated as screen coord when it's baseline coord or vice versa.

**Why it happens:** Baseline Y goes UP (positive = above baseline), screen Y goes DOWN (positive
= below top). Easy to forget which convention applies.

**How to avoid:** Document at each transform whether Y is baseline-relative or screen-relative.
Use separate variables when possible (`baseline_y` vs `screen_y`).

**Warning signs:** Glyphs upside down, ascenders pointing wrong direction.

Source: FreeType docs (bearing_y is upward), renderer.v line 100 shows conversion

### Pitfall 3: Incomplete Enum Coverage
**What goes wrong:** New orientation added to enum, old code paths don't handle it, silently
falls through to wrong behavior.

**Why it happens:** If statements don't require all cases. Easy to miss an update site.

**How to avoid:** Use match expressions for orientation dispatch. V compiler forces
exhaustiveness - adding new enum variant causes compilation error until all match sites updated.

**Warning signs:** Behavior that worked stops working after enum change.

Source: V language match behavior (GitHub issue #4239)

### Pitfall 4: Advance Direction Assumptions
**What goes wrong:** Code assumes x_advance always used, but vertical text uses y_advance.

**Why it happens:** Horizontal text is default, easy to hardcode x-only logic.

**How to avoid:** Separate upright/rotated functions that ONLY reference the relevant advance
direction. Makes assumptions explicit.

**Warning signs:** Vertical text stacks horizontally, pen doesn't move down.

Source: Current vglyph layout.v:656 shows y_advance logic for vertical

## Code Examples

Verified patterns from vglyph codebase and FreeType docs:

### Horizontal Glyph Positioning (Current Pattern)
```v
// Source: renderer.v lines 94-95, 125, 155
// Coordinate: cx/cy are logical pixels, baseline-relative
mut cx := x + f32(item.x)  // Layout-relative run start
mut cy := y + f32(item.y)  // Baseline Y

// Per-glyph positioning
target_x := cx + f32(glyph.x_offset)  // Logical X with glyph adjustment
// Convert to physical, snap to subpixel grid...
phys_origin_x := target_x * scale

// Final draw position (bearing offset from origin)
// Transform: screen_y = baseline_y - bearing_y (up->down conversion)
draw_x := (f32(draw_origin_x) + f32(cg.left)) * scale_inv
draw_y := (f32(draw_origin_y) - f32(cg.top)) * scale_inv
```

### Vertical Glyph Positioning (Current Pattern)
```v
// Source: layout.v lines 637-668, 689-698
if cfg.orientation == .vertical {
    // Manual stacking: horizontal layout info becomes vertical
    // Horizontal x_advance -> vertical y_advance (down)
    line_height := cfg.primary_ascent + cfg.primary_descent
    final_x_adv = 0.0
    final_y_adv = -line_height  // Negative moves pen DOWN (screen coords)

    // Center glyph horizontally in column
    center_offset := (line_height - x_adv) / 2.0
    final_x_off = center_offset

    // Run positioning: stack vertically
    final_run_x = run_y  // Horizontal baseline -> vertical position
    final_run_y = vertical_pen_y  // Cumulative vertical stack
    new_vertical_pen_y = vertical_pen_y + line_height * f64(glyph_count)
}
```

### FreeType Bearing Transform
```v
// Source: FreeType docs - glyph metrics
// bearingY: vertical distance from baseline to glyph top (upward positive)
// Screen rendering requires conversion to downward-positive coords

// Formula: screen_top = baseline_y - bearing_y
// Why: bearing_y measures UP from baseline, screen Y measures DOWN from top
render_y := pen_y - glyph.bearingY

// For bitmap drawing, add negative bearing_y to move down from baseline
draw_y := baseline_y - bearing_top  // bearing_top is positive upward value
```

### Exhaustive Orientation Match
```v
// Pattern: compiler-verified enum coverage
pos := match orientation {
    .horizontal {
        Position{
            x: pen_x + glyph.x_offset
            y: pen_y
            x_adv: glyph.x_advance
            y_adv: 0.0
        }
    }
    .vertical {
        Position{
            x: pen_x
            y: pen_y + glyph.y_offset
            x_adv: 0.0
            y_adv: glyph.y_advance
        }
    }
}
// Adding new orientation to enum without updating match -> compile error
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline conditional transforms | Separate functions per orientation | v1.1 pattern (Phase 6) | Testable, documented paths |
| Ad-hoc variable naming | Space-suffixed names (x_pango, x_logical) | Graphics best practice | Clear transform chains |
| If-else orientation checks | Match expressions for enums | V language standard | Compiler-verified exhaustiveness |
| Comments above transforms | Inline formula + rationale | v1.1 pattern (Phase 6) | Co-located with code |

**Current vglyph status:**
- Uses inline conditionals (old approach) - lines 637, 689
- Inconsistent coordinate space naming
- Some good inline docs (lines 638-667) but incomplete transform formulas
- No ASCII diagrams for complex transforms

## Open Questions

1. **Coordinate space for hit testing**
   - What we know: char_rects use Pango coordinates (compute_hit_test_rects line 792-868)
   - What's unclear: Should vertical text hit testing use transformed coords or original?
   - Recommendation: Test both orientations, ensure hit_test() works for vertical text

2. **Rotation vs vertical flow distinction**
   - What we know: .vertical is for upright CJK stacking, separate from rotated horizontal text
   - What's unclear: Is draw_layout_rotated() compatible with .vertical orientation?
   - Recommendation: Document draw_layout_rotated() as horizontal-only or test combination

3. **Subpixel positioning in vertical text**
   - What we know: Horizontal text snaps X to 1/4 pixel bins (renderer.v:130-136)
   - What's unclear: Should vertical text snap Y to subpixel bins?
   - Recommendation: Research vertical subpixel rendering practices, may need separate logic

## Sources

### Primary (HIGH confidence)
- FreeType Glyph Metrics: https://freetype.org/freetype2/docs/glyphs/glyphs-3.html
- W3C Vertical Text: https://www.w3.org/International/articles/vertical-text/
- vglyph codebase: layout.v lines 636-698, renderer.v lines 84-220
- Phase 6 patterns: .planning/phases/06-freetype-state/06-01-PLAN.md

### Secondary (MEDIUM confidence)
- Unicode Vertical Text Layout (UAX #50): https://www.unicode.org/reports/tr50/tr50-28.html
- V language GitHub issues on match exhaustiveness: https://github.com/vlang/v/issues/4239

### Tertiary (LOW confidence)
- Graphics coordinate transform tutorials (general CS education, not specific to text)
- Blender coordinate system notes (3D context, different from 2D text)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - V builtin match, FreeType standard, existing vglyph patterns
- Architecture: HIGH - FreeType official docs, W3C specs, verified vglyph code
- Pitfalls: MEDIUM - Based on common graphics programming errors, vglyph code inspection
- Code examples: HIGH - All examples extracted from vglyph codebase or FreeType docs

**Research date:** 2026-02-02
**Valid until:** ~60 days (stable domain - typography standards change slowly)
