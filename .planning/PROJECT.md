# VGlyph

## What This Is

Text rendering library for V language using Pango for shaping and FreeType for rasterization.
Atlas-based GPU rendering with layout caching, subpixel positioning, and rich text support.

## Core Value

Reliable text rendering without crashes or undefined behavior.

## Requirements

### Validated

- Text composition via Pango/HarfBuzz — existing
- Glyph rasterization via FreeType — existing
- Atlas-based GPU rendering — existing
- Layout caching with TTL eviction — existing
- Subpixel positioning (4 bins) — existing
- Rich text with styled runs — existing
- Hit testing and character rect queries — existing
- macOS accessibility integration — existing
- Error-returning GlyphAtlas API (`!GlyphAtlas`) — v1.0
- Dimension/overflow validation before allocation — v1.0
- 1GB max allocation limit with overflow protection — v1.0
- grow() error propagation through insert_bitmap — v1.0
- Pango pointer cast documented with debug validation — v1.0
- Inline object ID string lifetime management — v1.0

### Active

**v1.1 Fragile Area Hardening**

- [ ] Layout iteration state machine hardening (RAII wrappers, lifecycle validation)
- [ ] Pango attribute list lifecycle safety (ownership clarity, leak guards)
- [ ] FreeType face rendering state validation (sequence enforcement)
- [ ] Vertical text coordinate transformation safety (clearer transforms)

### Out of Scope

- Performance optimizations — separate concern (CONCERNS.md)
- Tech debt cleanup — separate concern (CONCERNS.md)
- Test coverage expansion — separate concern (CONCERNS.md)
- Dependency version pinning — separate concern (CONCERNS.md)
- Thread safety — V is single-threaded by design

## Context

VGlyph is a V language text rendering library. v1.0 hardened memory operations in glyph_atlas.v
and layout.v based on CONCERNS.md audit.

**Current State:**
- 8,301 LOC V
- Tech stack: Pango, FreeType, Cairo, OpenGL
- Memory/safety issues from CONCERNS.md addressed

**Files modified in v1.0:**
- `glyph_atlas.v` — Error-returning API, allocation validation, grow() propagation
- `layout.v` — Pointer cast docs, string cloning
- `layout_types.v` — cloned_object_ids field, destroy() method
- `renderer.v` — Callers handle GlyphAtlas errors

## Constraints

- **API Change**: new_glyph_atlas returns `!GlyphAtlas` instead of `GlyphAtlas`
- **V Language**: Uses V's error handling idioms (`!` return type, `or` blocks)
- **Performance**: Null checks in hot paths minimal overhead

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Return errors vs panic | Graceful degradation in production | Good - errors propagate cleanly |
| Debug-only validation | Runtime overhead acceptable only in debug | Good - catch issues in dev |
| Clone strings vs Arena | Arena adds complexity for string lifetime | Good - simple clone/free pattern |
| `or { panic(err) }` in renderer | Atlas failure unrecoverable at init | Good - matches existing examples |
| 1GB max allocation limit | Reasonable bound for glyph atlas | Good - prevents runaway growth |
| Silent errors in grow() | No log.error, just return error | Good - caller decides response |

---
*Last updated: 2026-02-02 after v1.1 milestone start*
