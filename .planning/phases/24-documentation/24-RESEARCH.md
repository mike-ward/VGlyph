# Phase 24: Documentation - Research

**Researched:** 2026-02-04
**Domain:** Code documentation, V language doc conventions, example file headers
**Confidence:** HIGH

## Summary

This phase covers documentation audit for vglyph. The codebase already has substantial documentation
including README.md, docs/API.md, docs/GUIDES.md, docs/ARCHITECTURE.md, and docs/ACCESSIBILITY.md.
The source files use V-style doc comments (function-prefixed `//` comments). The task is to verify
accuracy, add missing documentation, and ensure consistency with the established project conventions.

V language documentation follows Go-like patterns: comments immediately before declarations starting
with the function/type name. Multi-line docs use consecutive single-line `//` comments. The `vdoc`
tool generates HTML documentation from these comments. The project also uses a specific error
documentation format established in Phase 22: `// Returns error if:` followed by bullet list.

**Primary recommendation:** Systematically audit existing docs for accuracy against current code,
add header comments to example files, and document complex algorithms inline.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `v doc` | V 0.4+ | Generate documentation from source | V built-in |
| `v check-md` | V 0.4+ | Validate markdown files | V built-in |
| `v fmt` | V 0.4+ | Ensure code formatting | V built-in |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| GitHub markdown | - | README rendering | For README verification |

### Verification Commands
```bash
# Check markdown syntax
v check-md -w docs/API.md

# Generate and view documentation
v doc .

# Verify README examples compile
v -check-syntax examples/demo.v
```

## Architecture Patterns

### V Doc Comment Structure
```v
// function_name does something specific.
// Multi-line descriptions continue on subsequent lines.
//
// Returns error if:
// - condition one fails
// - condition two fails
pub fn function_name(param Type) !Result {
```

### Example File Header Format
```v
// example_name demonstrates [feature].
//
// Shows:
// - Feature one usage
// - Feature two usage
//
// Run: v run examples/example_name.v
module main
```

### Inline Algorithm Documentation
```v
// Algorithm:
// 1. First step description
// 2. Second step with rationale
//
// Trade-offs:
// - Pro: benefit
// - Con: cost
```

### Current Project File Structure
```
docs/
├── API.md           # Public API reference
├── GUIDES.md        # Feature tutorials
├── ARCHITECTURE.md  # System design
└── ACCESSIBILITY.md # Screen reader guide

examples/
├── demo.v           # Basic multilingual demo
├── editor_demo.v    # Text editing with IME
├── emoji_demo.v     # Emoji rendering
└── [15+ others]     # Feature demonstrations
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Doc generation | Custom markdown generator | `v doc` | V ecosystem standard |
| Markdown validation | Manual proofreading | `v check-md -w` | Catches structural errors |
| Code examples | Inline snippets | Link to examples/ files | Ensures examples actually run |
| API signature docs | Manually tracking | Review `v doc .` output | Shows actual signatures |

## Common Pitfalls

### Pitfall 1: Doc Comment Mismatch
**What goes wrong:** Doc comment describes different behavior than implementation
**Why it happens:** Code changed but comment not updated
**How to avoid:** Review `v doc` output against actual function behavior; grep for outdated
parameter names
**Warning signs:** Comment mentions parameters that don't exist; promises features not implemented

### Pitfall 2: Missing Error Documentation
**What goes wrong:** Function can return errors but doc doesn't list conditions
**Why it happens:** Error handling added incrementally without doc updates
**How to avoid:** Use established format: `// Returns error if:` with bullet list (per Phase 22)
**Warning signs:** Functions with `!` return type but no error conditions in doc

### Pitfall 3: README Instructions Drift
**What goes wrong:** README build steps don't work on fresh checkout
**Why it happens:** Dependencies change, API evolves, commands deprecated
**How to avoid:** Test README instructions on fresh environment; verify `v run examples/demo.v`
**Warning signs:** Issue reports about "can't build", old version numbers

### Pitfall 4: Undocumented Algorithms
**What goes wrong:** Complex code lacks explanation of why, not just what
**Why it happens:** Developer understands at write time, doesn't document
**How to avoid:** Document algorithm approach, trade-offs, and non-obvious choices inline
**Warning signs:** Nested loops without explanation; magic numbers; FreeType/Pango state changes

### Pitfall 5: Example Files Without Context
**What goes wrong:** User runs example, doesn't understand what it demonstrates
**Why it happens:** Examples written during development without audience consideration
**How to avoid:** Add header comment explaining purpose, features shown, how to run
**Warning signs:** `module main` with no preceding comment; demo names don't explain feature

## Code Examples

### Error Documentation Pattern (Phase 22 Convention)
```v
// Source: Phase 22 established pattern, api.v

// new_text_system creates a new TextSystem, initializing Pango context and
// Renderer.
//
// Returns error if:
// - FreeType library initialization fails
// - Pango font map creation fails
// - Pango context creation fails
pub fn new_text_system(mut gg_ctx gg.Context) !&TextSystem {
```

### Algorithm Documentation Pattern
```v
// Source: layout.v

// layout_text shapes, wraps, and arranges text using Pango.
//
// Algorithm:
// 1. Create transient `PangoLayout`.
// 2. Apply config: Width, Alignment, Font, Markup.
// 3. Iterate layout to decompose text into visual "Run"s (glyphs sharing font/attrs).
// 4. Extract glyph info (index, position) to V `Item`s.
// 5. "Bake" hit-testing data (char bounding boxes).
//
// Trade-offs:
// - **Performance**: Shaping is expensive. Call only when text changes.
//   Resulting `Layout` is cheap to draw.
// - **Memory**: Duplicates glyph indices/positions to V structs to decouple
//   lifecycle from Pango.
```

### Example File Header Pattern
```v
// Source: Recommended pattern based on editor_demo.v

// editor_demo demonstrates vglyph text editing capabilities.
//
// Features shown:
// - Cursor navigation (arrows, word/line jumps)
// - Text selection (click, double-click, triple-click)
// - IME composition (Japanese, Chinese, Korean input)
// - Undo/redo support
//
// Run: v run examples/editor_demo.v
module main
```

### Inline Comment for Complex Logic
```v
// Source: glyph_atlas.v

// Subpixel Positioning:
// If we are shifting (bin > 0), we must load the outline, translate it, then render.
// We cannot use FT_LOAD_RENDER directly because it renders the unshifted glyph.
should_shift := cfg.subpixel_bin > 0
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Sparse inline comments | Algorithm + trade-off docs | Phase 22 | Better maintainability |
| Ad-hoc error docs | `// Returns error if:` pattern | Phase 22 | Consistent error docs |
| No example headers | Header comment convention | Phase 24 | User clarity |

**Current codebase documentation state:**
- README.md: Well-structured with prerequisites, quickstart, examples
- docs/API.md: Comprehensive but needs accuracy verification
- docs/GUIDES.md: Feature tutorials present
- docs/ARCHITECTURE.md: System design documented
- Example files: Most lack header comments explaining purpose
- Inline algorithm docs: Present in layout.v, glyph_atlas.v; needs consistency check

## Requirements Mapping

| Requirement | Key Files | Verification Method |
|-------------|-----------|---------------------|
| DOC-01: API comments match behavior | api.v, context.v, renderer.v | Compare `v doc` output to actual signatures |
| DOC-02: Deprecated APIs marked | *.v | Grep for deprecated patterns (none found) |
| DOC-03: README build works | README.md | Run instructions on fresh checkout |
| DOC-04: README features match | README.md | Verify each feature claim |
| DOC-05: README examples work | README.md | Extract code blocks, run |
| DOC-06: Complex logic commented | layout.v, glyph_atlas.v | Review complex functions |
| DOC-07: Algorithms documented | layout.v, glyph_atlas.v | Check shaping/packing docs |
| DOC-08: Example headers | examples/*.v | Add missing headers |

## Files Requiring Attention

### Public API Files (DOC-01)
- `api.v` - TextSystem methods
- `context.v` - Context methods
- `renderer.v` - Renderer methods
- `layout_query.v` - Layout query methods
- `layout_mutation.v` - Mutation functions
- `layout_types.v` - Type definitions

### Complex Algorithm Files (DOC-06, DOC-07)
- `layout.v` - Text shaping/layout (has docs, verify complete)
- `glyph_atlas.v` - Atlas packing (has docs, verify complete)
- `layout_query.v` - Hit testing, cursor movement (partial docs)
- `composition.v` - IME composition state

### Example Files Needing Headers (DOC-08)
Current examples without proper headers:
- `atlas_resize_debug.v`
- `atlas_debug.v`
- `accessibility_simple.v`
- `list_demo.v`
- `typography_demo.v`
- `rich_text_demo.v`
- `api_demo.v`
- `demo.v`
- `crisp_demo.v`
- `subpixel_demo.v`
- `subpixel_animation.v`
- `rotate_text.v`
- `style_demo.v`
- `stress_demo.v`
- `inline_object_demo.v`
- `icon_font_grid.v`
- `showcase.v`
- `variable_font_demo.v`
- `emoji_demo.v`
- `size_test_demo.v`
- `check_system_fonts.v`

Only `editor_demo.v` has proper header documentation.

## Open Questions

1. **Deprecated API discovery**
   - What we know: Grep found no `@[deprecated]` or `// Deprecated` markers
   - What's unclear: Are there any APIs that should be deprecated but aren't marked?
   - Recommendation: Review for obsolete patterns; if none found, DOC-02 is N/A

2. **Feature completeness verification**
   - What we know: README lists many features
   - What's unclear: All features work as advertised?
   - Recommendation: Test each feature claim during DOC-04 verification

## Sources

### Primary (HIGH confidence)
- V language documentation: https://docs.vlang.io/writing-documentation.html
- Project source files: api.v, layout.v, glyph_atlas.v (direct examination)
- Phase 22 conventions: .planning/phases/22-security-audit/

### Secondary (MEDIUM confidence)
- V standard library examples at modules.vlang.io (pattern verification)

## Metadata

**Confidence breakdown:**
- Documentation patterns: HIGH - V docs official, codebase reviewed
- Algorithm locations: HIGH - Direct file examination
- Example file list: HIGH - Direct glob
- Deprecated API status: MEDIUM - Grep-based, may miss edge cases

**Research date:** 2026-02-04
**Valid until:** 60 days (documentation patterns stable)
