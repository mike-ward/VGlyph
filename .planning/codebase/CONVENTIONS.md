# Coding Conventions

**Analysis Date:** 2026-02-01

## Naming Patterns

**Files:**
- Test files use leading underscore: `_api_test.v`, `_layout_test.v`, `_font_height_test.v`
- Regular source files use lowercase: `api.v`, `layout.v`, `context.v`, `renderer.v`
- No file name prefixes; modules define visibility via `pub` keyword

**Functions:**
- Snake case for all function names: `new_context()`, `layout_text()`, `draw_layout()`,
  `get_or_create_layout()`
- Receiver methods use same snake case: `(mut ctx Context) layout_text(...)`
- Constructor functions named `new_*`: `new_context()`, `new_renderer()`, `new_text_system()`
- Test functions prefixed with `test_`: `test_context_creation()`, `test_layout_simple_text()`

**Variables:**
- Snake case for all variable names: `scale_factor`, `visual_height`, `char_rects`
- Single-letter variables only in tight loops: `for i in 0 .. 256`, `for run in rt.runs`
- Temporary accumulator use short prefix: `mut full_text` (for building strings), `mut valid_runs`
- Cached values use clear suffix: `last_access`, `eviction_age`

**Types:**
- Pascal case for all types: `TextSystem`, `TextConfig`, `BlockStyle`, `TextStyle`
- Enum names in Pascal case: `Alignment`, `WrapMode`, `Typeface`
- Enum variants in lowercase: `.left`, `.center`, `.right`, `.word`, `.bold`
- Struct field names in snake case: `font_name`, `char_rects`, `glyph_start`

**Constants:**
- Snake case for constants: `space_char`, `gamma_table`, `fnv_offset_basis`, `pango_glyph_unknown_flag`
- Prefix compound constants: `window_width`, `window_height`, `crisp_win_width`

## Code Style

**Formatting:**
- Tabs for indentation (enforced in `.editorconfig`)
- Final newline at end of file
- Trim trailing whitespace
- UTF-8 charset

**Linting:**
- No explicit linter config present; rely on `v fmt` built-in formatter
- Format check: Run `v check-md -w <file>` for markdown files
- Syntax check: Run `v -check-syntax <file>` for V files

**Blank Lines:**
- Single blank line between functions and method implementations
- Blank lines preserve readability in longer structs (see `Item` struct with flag grouping)

## Import Organization

**Order:**
1. Built-in V modules: `import gg`, `import log`, `import math`, `import strings`
2. Standard library modules: `import time`, `import os`
3. External crates: `import sokol.sapp`, `import sokol.gfx as sg`, `import sokol.sgl`
4. Internal modules: `import vglyph`, `import accessibility`

**Path Aliases:**
- Use full imports without aliases by default
- Alias only when importing for its side-effects: `import gg as _` (in test files)
- Rename for brevity in specific contexts: `import sokol.gfx as sg`

**Module Declaration:**
- All files in a package share same module: `module vglyph`, `module accessibility`
- Declare at top of every file before imports

## Error Handling

**Patterns:**
- Use `!Type` syntax for fallible functions: `fn new_context(scale_factor f32) !&Context`
- Propagate errors with `!` operator: `layout := ctx.layout_text(text, cfg)!`
- Explicitly handle errors with `or { ... }` blocks when recovery needed:
  ```v
  mut ctx := new_context(1.0) or {
      assert false, 'Failed to create context: ${err}'
      return
  }
  ```
- Log errors before returning: `log.error('${@FILE_LINE}: Failed to ...')` followed by `return error(...)`
- Return descriptive error strings: `error('Failed to create Pango Font Map')`
- Use `?Type` syntax for optional values (not errors): `pub fn hit_test_rect(x f32, y f32) ?gg.Rect`
- Use `or { return none }` for optional chains: `rect_idx := l.char_rect_by_index[index] or { return none }`
- Use `or { continue }` to skip in loops: `rect_idx := l.char_rect_by_index[i] or { continue }`

**Error Location Tracking:**
- Include file/line in error logs: `log.error('${@FILE_LINE}: message')`
- Helps debug in complex C FFI contexts

## Logging

**Framework:** Built-in `log` module

**Patterns:**
- Log errors only at initialization or critical paths: `log.error(msg)`
- Debug output via `println()` in tests and examples: `println('Font height: ${height}')`
- No explicit logging levels beyond error; use assertions for test validation

## Comments

**When to Comment:**
- Function purpose: Describe what, not how
- Algorithm steps: Break down multi-step operations
- Tradeoffs: Document design decisions
- TODO/FIXME: Mark incomplete work (e.g., `// TODO`, `// Set Label (Commented out)`)

**Documentation Comments:**
- Use `//` for function docs immediately before declaration
- Describe parameters and return values in prose
- Link to external config structures with markdown syntax: `[TextConfig](#TextConfig)`
- Example from `api.v`:
  ```v
  // draw_text renders text string at (x, y) using configuration.
  // Handles layout caching to optimize performance for repeated calls.
  // [TextConfig](#TextConfig)
  pub fn (mut ts TextSystem) draw_text(...) ! { ... }
  ```

**Multi-line Comments:**
- Document algorithms at top of function:
  ```v
  // Algorithm:
  // 1. Create transient PangoLayout.
  // 2. Apply config...
  // 3. Iterate layout...
  ```

**Inline Comments:**
- Explain non-obvious calculations or C FFI usage
- Justify design choices: `// Cache pruning only activates when cache exceeds 10,000`
- Note metadata: `// char byte index -> char_rects array index`

## Function Design

**Size:** 20-50 lines typical; larger functions factor complex steps into helpers

**Parameters:**
- Max 3-4 direct parameters; use config structs for many options (see `TextConfig`)
- Receiver parameters as `mut` when modification needed: `fn (mut ctx Context)`
- Receiver parameters as immutable `&` when read-only: `fn (renderer &Renderer)`

**Return Values:**
- Single return type, optionally wrapped in error: `!f32`, `?gg.Rect`, `[]gg.Rect`
- Void functions for side-effects only: `pub fn commit()`
- Return named types from complex operations: `Layout`, `CachedGlyph`

**Mutation:**
- Mark params as `mut` if modified: `fn (mut ctx Context)`, `fn (mut app AppDemo)`
- Use `mut` variables inside functions when accumulating: `mut full_text`, `mut valid_runs`

## Module Design

**Exports:**
- Use `pub` prefix for all exported functions and types
- No exported private helpers; factored code as private functions: `fn (mut ctx Context) add_font_file(...)`
- Private internal structs like `CachedLayout` use `pub` but are not re-exported

**Barrel Files:**
- No barrel files (no `index.v` re-exporting)
- One module per directory (`accessibility/`)
- Files within module share all symbols (no `pub` needed for cross-file visibility within module)

**Type Visibility:**
- Public types use `pub struct`/`pub enum`
- Fields split `pub` (readable) and `pub mut` (mutable):
  ```v
  pub struct Layout {
  pub mut:
      items []Item
  pub:
      width f32
  }
  ```

## Struct Field Organization

**Convention:** Group related fields, use comments to explain semantic relationships

**Example from `Item`:**
```v
pub struct Item {
pub:
    run_text  string
    ft_face   &C.FT_FaceRec
    // ... basic properties ...
    glyph_start int
    glyph_count int
    // ... decorations ...
    underline_offset        f64
    underline_thickness     f64
    // ... flags ...
    has_underline      bool
    has_strikethrough  bool
    use_original_color bool // Comment explains purpose
}
```

Rationale: `// Flags (grouped to pack into bytes...)`

## Pointer Safety

**Unsafe Blocks:**
- Used for C interop: `unsafe { nil }` when initializing null pointers
- Justified in comments when semantically important: `// Initialize pointer to null`
- Cache raw C pointers like `&C.FT_FaceRec` without unsafe wrapping (implied safe via C API)

## Performance Annotations

**Caching:** Document cache semantics in comments
- `get_or_create_layout()`: Caches Layout by FNV hash
- Cache pruning: "Cache pruning only activates when cache exceeds 10,000 entries"

**Lazy Loading:** Noted in docstrings and algorithm sections
- "Lazy loading may cause CPU spike on first frame with new text"

## Interface Patterns

**Backends:** Use embedded structs for default implementations
- `AccessibilityBackend` interface defined in `accessibility/backend.v`
- Darwin and Stub implementations separate files with same function signatures

**Builder Pattern:**
- Config structs like `TextConfig` act as option builders
- Defaults set at field declaration: `width: -1.0`, `align: .left`

---

*Convention analysis: 2026-02-01*
