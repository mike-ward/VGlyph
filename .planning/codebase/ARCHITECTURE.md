# Architecture

**Analysis Date:** 2026-02-01

## Pattern Overview

**Overall:** Layered Client Library with Text Composition Pipeline

vglyph implements a three-layer architecture separating concerns:
1. **Text Composition Layer**: Pango/HarfBuzz shaping and layout
2. **Rendering Layer**: Glyph rasterization and atlas management
3. **API Layer**: High-level user interface with caching

Key Characteristics:
- Text is treated as a composition problem (shaping → layout → render)
- Lazy-loaded glyph rendering with atlas packing
- Layout-caching system reduces redundant shaping work
- Platform-specific accessibility bindings (macOS via Objective-C)
- Subpixel positioning for anti-aliased rendering

## Layers

**Composition Layer:**
- Purpose: Shape text using Pango+HarfBuzz, compute layout (items, glyphs, metrics)
- Location: `layout.v`, `layout_types.v`, `c_bindings.v`
- Contains: Pango FFI bindings, layout algorithm, text shape calculation
- Depends on: FreeType, Pango, HarfBuzz, FontConfig C libraries
- Used by: TextSystem API layer

**Rendering Layer:**
- Purpose: Rasterize glyphs to atlas, batch-draw via Sokol/gg
- Location: `renderer.v`, `glyph_atlas.v`, `bitmap_scaling.v`
- Contains: Glyph caching, atlas allocation, subpixel rasterization, gamma correction
- Depends on: FreeType glyph outlines, gg graphics context, Sokol GPU API
- Used by: TextSystem API layer

**API Layer:**
- Purpose: User-facing interface with layout caching and lifecycle management
- Location: `api.v`, `context.v`
- Contains: TextSystem struct, cache management, draw_text operations
- Depends on: Composition and Rendering layers
- Used by: Application code (examples)

**Accessibility Layer:**
- Purpose: Convert rendered layouts to screen reader nodes
- Location: `layout_accessibility.v`, `accessibility/`
- Contains: Text node creation, macOS accessibility bridge
- Depends on: Layout structs
- Used by: TextSystem when enabled

**Query Layer:**
- Purpose: Inspect layouts (hit testing, character bounds)
- Location: `layout_query.v`
- Contains: Hit-test algorithms, character rect lookup
- Depends on: Layout structs
- Used by: Applications doing text interaction

## Data Flow

**Text Rendering Flow:**

1. **Input**: User calls `ts.draw_text(x, y, text, config)`
2. **Cache Lookup**: TextSystem checks layout cache using FNV-1a hash
3. **Layout (if miss)**:
   - Context creates Pango layout from text + config
   - Pango shapes text with HarfBuzz, produces runs/glyphs
   - Layout extracts V structs (Items, Glyphs, CharRects)
   - Result cached with TTL-based eviction
4. **Rendering**:
   - For each item in layout:
     - For each glyph in item:
       - Check renderer glyph cache (FreeType + atlas position)
       - If miss: Load glyph via FreeType, rasterize, pack to atlas
       - Queue textured quad draw (Sokol)
   - Renderer marks atlas dirty if new glyphs added
5. **GPU Sync**: `ts.commit()` called once per frame uploads atlas to GPU

**Rich Text Flow:**

1. **Input**: User provides RichText with styled runs
2. **Composition**:
   - Concatenate all run text to build full paragraph
   - Create base Pango layout (global config)
   - Apply per-run style overrides as Pango attributes
3. **Rendering**: Same as simple text flow

**State Management:**

- **Layout Cache**: map[u64]&CachedLayout
  - Key: FNV-1a hash of (text, all config fields)
  - Value: Cached layout + access timestamp
  - Eviction: Mark-and-sweep when cache > 10,000 entries
- **Glyph Cache**: map[u64]CachedGlyph (per Renderer)
  - Key: (glyph index << 2) | subpixel_bin
  - Value: Atlas position (x, y, width, height)
- **Pango Context**: Global, reused across all text operations
- **Glyph Atlas**: Dynamic texture, grows/reallocates as needed

## Key Abstractions

**TextSystem:**
- Purpose: Orchestrates composition + rendering + caching
- Examples: `api.v` lines 15-40
- Pattern: Single mutable struct holding context, renderer, caches

**Context:**
- Purpose: Lifecycle management for FreeType, Pango, FontConfig
- Examples: `context.v` lines 6-78
- Pattern: Initialized once, reused globally; must be freed on shutdown

**Layout:**
- Purpose: Immutable output of text shaping; contains items, glyphs, metrics
- Examples: `layout_types.v` lines 5-16
- Pattern: Value type (cheap to copy); decomposed from transient Pango structures

**Item:**
- Purpose: Represents a run of glyphs sharing font, style, and metrics
- Examples: `layout_types.v` lines 32-64
- Pattern: Contains glyph index range (glyph_start, glyph_count) plus rendering state

**Renderer:**
- Purpose: Lazy-loads glyphs, manages atlas, queues GPU draws
- Examples: `renderer.v` lines 16-24
- Pattern: Mutable, stateful; holds both CPU caches and GPU resources

**GlyphAtlas:**
- Purpose: Bin-packing texture for rasterized glyphs
- Examples: `glyph_atlas.v` lines 22-35
- Pattern: Dynamic allocation; grows when full; cleans up unused glyphs

## Entry Points

**TextSystem Initialization:**
- Location: `api.v` lines 29-40
- Triggers: `vglyph.new_text_system(mut gg_ctx)` called by application
- Responsibilities: Initialize Context (Pango/FreeType), create Renderer, empty cache

**Text Drawing:**
- Location: `api.v` lines 57-65
- Triggers: `ts.draw_text(x, y, text, cfg)`
- Responsibilities: Get or create layout, render to screen, update accessibility

**Frame Commit:**
- Location: `api.v` lines 95-101
- Triggers: `ts.commit()` called once per frame
- Responsibilities: Upload dirty atlas to GPU, prune layout cache, commit accessibility

**Layout Computation:**
- Location: `layout.v` lines 25-37
- Triggers: `ctx.layout_text(text, cfg)` (internal via TextSystem)
- Responsibilities: Call Pango, extract V structs, compute hit-test data

## Error Handling

**Strategy:** Result-based (V's `!` error propagation)

**Patterns:**
- Library initialization (`new_context`, `new_text_system`) returns `!&Type`
- Drawing operations (`draw_text`, `layout_text`) return `!`
- Query operations (`hit_test_rect`, `get_char_rect`) use optional types (`?`)
- C library failures logged, wrapped in error string, propagated up
- Examples: `context.v` lines 26-48 (FreeType/Pango init error handling)

## Cross-Cutting Concerns

**Logging:** Uses V's `log` module
- Format: `log.error('${@FILE_LINE}: message')` in error paths
- Location: `context.v`, `layout.v`, where C library calls fail
- Not used for debug output (examples: `examples/` files use println)

**Validation:** Compile-time via V type system + runtime assertions
- Assert patterns: `assert condition, 'message'` in glyph_atlas.v
- Type safety: Enum types (Alignment, WrapMode, Typeface) prevent invalid states
- Examples: `glyph_atlas.v` lines 48-53 (dimension overflow check)

**Authentication:** Not applicable (client library with no network)

**DPI/Scale Handling:** Baked into Context and Renderer
- Scale factor passed at init time: `Context.scale_factor`, `Renderer.scale_factor`
- All measurements converted: physical pixels ↔ logical points
- Subpixel rasterization: Glyphs pre-rendered at 4 subpixel positions (bins)
- Examples: `renderer.v` lines 118-136 (subpixel positioning)

**Accessibility Integration:** Optional, per-frame updates
- Enabled: `ts.enable_accessibility(true)`
- Collects text + bounding boxes from layout
- Backend: Platform-specific (macOS AXUIElement bridge, stub for others)
- Examples: `layout_accessibility.v` lines 10-29
