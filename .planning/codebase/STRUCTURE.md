# Codebase Structure

**Analysis Date:** 2026-02-01

## Directory Layout

```
vglyph/
├── api.v                      # TextSystem public API (draw, measure, cache)
├── context.v                  # Pango/FreeType initialization & lifecycle
├── renderer.v                 # Glyph rendering & atlas management
├── glyph_atlas.v              # Atlas bin-packing & dynamic texture
├── layout.v                   # Pango layout composition algorithm
├── layout_types.v             # Type definitions (Layout, Item, Glyph, etc.)
├── layout_query.v             # Hit testing & character bounds queries
├── layout_accessibility.v     # Screen reader integration
├── c_bindings.v               # FreeType/Pango/HarfBuzz FFI declarations
├── bitmap_scaling.v           # Glyph rasterization & gamma correction
├── accessibility/             # Platform-specific accessibility backends
│   ├── manager.v
│   ├── accessibility_types.v
│   ├── backend.v
│   ├── backend_darwin.v       # macOS AXUIElement bridge
│   ├── backend_stub.v         # No-op for non-macOS
│   ├── objc_bindings_darwin.v
│   └── objc_helpers.h
├── examples/                  # Reference implementations
│   ├── api_demo.v
│   ├── emoji_demo.v
│   ├── editor_demo.v
│   ├── stress_demo.v
│   └── ...
├── assets/                    # Fonts & test data
├── docs/                      # Documentation & API reference
├── v.mod                      # V module manifest
├── v-check.vsh                # Syntax & format validation
├── _*_test.v                  # Unit tests (co-located)
└── ft_compat.h                # FreeType compatibility header
```

## Directory Purposes

**Root Level (Core Library):**
- Purpose: Core text rendering engine API, composition, and rendering
- Contains: `.v` source files (11 files), v.mod manifest
- Key files: `api.v` (entry point), `layout.v` (main algorithm), `renderer.v`

**accessibility/**
- Purpose: Platform-specific accessibility/screen reader integration
- Contains: Type definitions, manager, platform backends
- Key files: `manager.v` (orchestrator), `backend_darwin.v` (macOS)
- Note: Conditional compilation (`$if macos { }`)

**examples/**
- Purpose: Reference implementations showing API usage patterns
- Contains: Standalone V programs demonstrating features
- Key files: `api_demo.v` (basic usage), `editor_demo.v` (complex interaction)
- Not compiled into library; used for development validation

**assets/**
- Purpose: Test fonts and sample data
- Contains: Font files for testing/examples
- Generated: No; committed

**docs/**
- Purpose: Public documentation (API reference, examples, guides)
- Contains: Markdown files, architecture notes
- Generated: No; hand-written

## Key File Locations

**Entry Points:**
- `api.v`: TextSystem public interface (draw_text, text_width, text_height, commit)
- `context.v`: Context initialization (new_context, font loading)
- `renderer.v`: Renderer initialization (new_renderer, new_renderer_atlas_size)

**Configuration:**
- `v.mod`: Module manifest (name, version, dependencies)
- `c_bindings.v`: FFI flags and C struct definitions

**Core Logic:**
- `layout.v`: Text shaping algorithm (layout_text, layout_rich_text, build_layout_from_pango)
- `renderer.v`: Glyph loading and drawing (draw_layout, get_or_load_glyph, commit)
- `glyph_atlas.v`: Texture management (new_glyph_atlas, resize, cleanup)

**Type Definitions:**
- `layout_types.v`: All public types (Layout, Item, Glyph, TextConfig, TextStyle, etc.)

**Testing:**
- `_api_test.v`: TextSystem API tests
- `_layout_test.v`: Layout composition tests
- `_text_height_test.v`: Font metrics tests
- `_font_resource_test.v`: Font loading tests
- Located alongside source files (co-located pattern)

**Queries & Interaction:**
- `layout_query.v`: Hit testing (hit_test, hit_test_rect, get_closest_offset)
- `layout_accessibility.v`: A11y node creation (update_accessibility)

## Naming Conventions

**Files:**
- Main modules: lowercase with underscores (`api.v`, `glyph_atlas.v`)
- Test files: `_prefix_test.v` or `_prefix_test.v`
- Type definitions: Grouped in `*_types.v` files (`layout_types.v`)
- Platform-specific: `*_darwin.v`, `*_stub.v` (macOS vs others)
- Examples: `verb_noun.v` (`api_demo.v`, `emoji_demo.v`)

**Functions:**
- Public: PascalCase (e.g., `new_text_system`, `draw_text`)
- Private: snake_case (e.g., `build_layout_from_pango`, `get_cache_key`)
- Constructors: `new_*` pattern (e.g., `new_context`, `new_renderer`)

**Types:**
- Public: PascalCase (e.g., `TextSystem`, `Layout`, `TextConfig`)
- Private: PascalCase (e.g., `CachedLayout`)
- Constants: UPPER_SNAKE_CASE (e.g., `pango_glyph_unknown_flag`, `pango_scale`)

**Variables:**
- Fields: snake_case (e.g., `glyph_start`, `bg_color`)
- Mut fields: Marked with `mut:` in struct declaration
- Pointers: Prefixed with `&` (e.g., `&Context`, `&C.PangoFontMap`)

## Where to Add New Code

**New Feature (text decoration, new shape, etc.):**
- Primary code: Extend `layout.v` (composition) or `renderer.v` (rendering)
- Types: Add to `layout_types.v` (enum, struct)
- Tests: Create `_feature_test.v` next to implementation

**New Query Function (e.g., word boundary detection):**
- Implementation: `layout_query.v`
- Signature: `pub fn (l Layout) query_name(...) type`
- Tests: `_layout_query_test.v` (if not covered in `_layout_test.v`)

**New Accessibility Capability:**
- Types: Add to `accessibility/accessibility_types.v`
- Logic: Add method to `accessibility/manager.v`
- Backend: Implement in `accessibility/backend_darwin.v` and `backend_stub.v`

**Utilities (e.g., font loading helpers):**
- Shared helpers: `context.v` (font-related) or new `utilities.v`
- Private helpers: Same file as caller

**Platform-Specific Code:**
- Pattern: `$if macos { code } $else { code }`
- Location: Keep in main file if small; separate to `*_darwin.v` if large
- Examples: `context.v` lines 50-69 (system font discovery on macOS)

## Special Directories

**assets/**
- Purpose: Font files for testing/examples
- Generated: No
- Committed: Yes (via git-lfs or direct)

**docs/**
- Purpose: Public API documentation
- Generated: No (hand-written)
- Committed: Yes

**examples/**
- Purpose: Working reference code
- Generated: No
- Committed: Yes
- Note: Can be run with `v examples/api_demo.v`

**.planning/**
- Purpose: GSD internal planning documents
- Generated: Yes (by GSD tools)
- Committed: No (typically in .gitignore)

## File Dependencies Graph

```
(High-Level)
api.v → context.v
      → renderer.v
      → layout.v
      → accessibility/manager.v

(Composition)
layout.v → layout_types.v
        → c_bindings.v
        → context.v

(Rendering)
renderer.v → glyph_atlas.v
          → bitmap_scaling.v
          → c_bindings.v
          → layout_types.v

(Accessibility)
accessibility/manager.v → accessibility/backend_darwin.v
                       → accessibility/accessibility_types.v

(Queries)
layout_query.v → layout_types.v

(Tests)
_*_test.v → api.v, layout.v, renderer.v, etc.
```

## Key Patterns

**Mutable Receiver Pattern:**
- All initialization methods take `mut` parameter: `fn init(mut ctx Context)`
- Drawing methods take `mut` receiver: `fn (mut ts TextSystem) draw_text(...)`
- Rationale: Track cache changes, dirty flags, GPU sync

**Lazy-Load Pattern:**
- Glyphs loaded on-demand in `renderer.draw_layout()`
- Layouts computed on-demand in `TextSystem.get_or_create_layout()`
- Reduces startup time; first frame may be slower

**Caching Pattern:**
- FNV-1a hash function for fast key generation (`api.v` lines 191-224)
- Layout cache: Text + config → Layout (with TTL eviction)
- Glyph cache: (index, subpixel_bin) → Atlas position
- Renderer-level glyph cache checked first, then FreeType fallback

**Error Propagation:**
- Use V's `!` operator for Result types
- Wrap C library errors: Extract error reason, wrap in `error(msg)`
- Example: `context.v` line 27 (`return error('...')`)

**FFI Bindings:**
- Location: `c_bindings.v`
- Pattern: `#pkgconfig`, `@[typedef]`, C struct definitions
- Pointers always checked against `unsafe { nil }` before use

**Type Safety via Enums:**
- Alignment, WrapMode, TextOrientation, Typeface defined as enums
- Prevents invalid string-based config
- Pango match on enum variants, not strings
