# Phase 6: FreeType State - Research

**Researched:** 2026-02-02
**Domain:** FreeType glyph slot state transitions, V debug-only validation patterns
**Confidence:** HIGH

## Summary

Researched FreeType glyph slot state requirements for load->translate->render sequence validation in V
language FFI wrapper. FreeType glyph operations have implicit state prerequisites: `FT_Load_Glyph`
requires initialized face size, `FT_Outline_Translate` requires loaded outline (not bitmap),
`FT_Render_Glyph` requires loaded glyph data. Current codebase (`glyph_atlas.v:load_glyph`) handles
these correctly via conditional flags and fallback reload, but lacks documentation and debug
validation.

The fallback path (lines 186-191) correctly handles bitmap fonts by catching `FT_Render_Glyph`
failure and reloading with `FT_LOAD_RENDER`. Both paths produce valid bitmap output. Debug
validation should check prerequisites before each operation to catch misuse early.

**Primary recommendation:** Add prerequisite checks at each operation site, document state
requirements inline, verify fallback path follows same sequence invariants.

## Standard Stack

### Core Language Features
| Feature | Purpose | Why Standard |
|---------|---------|--------------|
| `$if debug` | Debug-only checks | Conditional compilation, zero release overhead |
| `panic(msg)` | Fatal state errors | Immediate failure on invalid state (Phase 4/5 pattern) |
| Inline comments | State documentation | Brief prerequisites at each FT operation |

### Supporting
| Feature | Purpose | When to Use |
|---------|---------|-------------|
| `std.debug.assert` | Could be alternative | V uses panic for debug guards, not assert |
| Enum state tracking | Per-slot state machine | Overkill for prerequisite checks (see Discretion) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Operation-site checks | Per-face state enum | Enum adds complexity; checks are simpler and match FT API |
| Panic on bad state | Return error | Debug should panic (per CONTEXT.md), prod silently fails |
| Inline docs | External diagram | Brief inline better; ASCII diagram optional |

**Installation:**
N/A - built-in language features + FreeType C library

## Architecture Patterns

### Recommended State Validation Pattern
```v
// FT_Outline_Translate requires:
// - Glyph loaded via FT_Load_Glyph (not with FT_LOAD_RENDER for outline)
// - Outline format (FT_GLYPH_FORMAT_OUTLINE), not bitmap
// Debug check: should_shift implies outline available

$if debug {
    if should_shift && glyph.outline.n_points == 0 {
        panic('FT_Outline_Translate requires loaded outline, got empty. ' +
              'Check FT_Load_Glyph flags exclude FT_LOAD_RENDER.')
    }
}
C.FT_Outline_Translate(&glyph.outline, shift, 0)
```

### Pattern 1: Prerequisite Check Before FT Call
**What:** Check state conditions before calling FT function
**When to use:** Each FT operation that has state requirements
**Example:**
```v
// Requires: glyph loaded (face.glyph valid after FT_Load_Glyph success)
$if debug {
    if cfg.face.glyph == unsafe { nil } {
        panic('FT_Render_Glyph requires loaded glyph. ' +
              'See: glyph_atlas.v state machine.')
    }
}
if C.FT_Render_Glyph(glyph, render_mode) != 0 {
    // fallback...
}
```

### Pattern 2: Inline State Documentation
**What:** Brief comment documenting prerequisite before FT call
**When to use:** Every FT_Load_Glyph, FT_Outline_Translate, FT_Render_Glyph
**Example:**
```v
// State: face initialized, size set via Pango (implicit)
// Requires: valid glyph index
if C.FT_Load_Glyph(cfg.face, cfg.index, flags) != 0 {
```

### Pattern 3: Fallback Path Verification
**What:** Ensure fallback follows same state sequence
**When to use:** When render fails and reload is attempted
**Example:**
```v
if C.FT_Render_Glyph(glyph, render_mode) != 0 {
    // Fallback: reload with immediate render (bitmap fonts)
    // State: resets to post-load state, no translate needed
    // Requires: same face/index validity as original load
    if C.FT_Load_Glyph(cfg.face, cfg.index, ...) != 0 {
        return error('...')
    }
    // glyph now has bitmap directly, no FT_Render_Glyph needed
}
```

### Anti-Patterns to Avoid
- **Translate after render:** Outline consumed, bitmap exists - translate does nothing useful
- **Render without load:** Glyph slot empty, undefined behavior
- **Multiple loads without handling:** Each load erases previous slot content

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| State machine enum | Custom enum + transitions | Prerequisite checks | FT API is stateless-per-call |
| Runtime state tracking | Map<face, state> | Debug checks at call site | Simpler, matches Phase 4/5 |
| Custom error recovery | Complex retry logic | Existing fallback pattern | Already works, just document |

**Key insight:** FreeType's state is implicit in the glyph slot (face->glyph). Each operation
transforms slot content. Check prerequisites, don't track full state machine.

## Common Pitfalls

### Pitfall 1: Translating Empty Outline
**What goes wrong:** `FT_Outline_Translate` on null/empty outline causes undefined behavior
**Why it happens:** FT_LOAD_RENDER was used (renders immediately), or bitmap font loaded
**How to avoid:** Check `should_shift` implies non-bitmap path; verify outline has points
**Warning signs:** Crash in FT_Outline_Translate, garbled glyph rendering

### Pitfall 2: Rendering Already-Rendered Glyph
**What goes wrong:** Calling FT_Render_Glyph on bitmap slot is wasteful/undefined
**Why it happens:** FT_LOAD_RENDER already rendered in load step
**How to avoid:** Track whether render was deferred; only call if outline path taken
**Warning signs:** No visual issue, but wasted CPU

### Pitfall 3: Assuming Outline After Load
**What goes wrong:** Bitmap fonts have no outline; translate/render sequence fails
**Why it happens:** Font is bitmap-only (emoji, pixel fonts)
**How to avoid:** Handle FT_Render_Glyph failure gracefully; reload with FT_LOAD_RENDER
**Warning signs:** Emoji or bitmap fonts fail to render

### Pitfall 4: Forgetting Size Initialization
**What goes wrong:** FT_Load_Glyph needs initialized FT_Size for meaningful metrics
**Why it happens:** Face created but size not set
**How to avoid:** Pango handles this implicitly; document that face comes from Pango with size set
**Warning signs:** Zero-size glyphs, incorrect metrics

## Code Examples

Verified patterns from FreeType docs and existing codebase:

### Current Codebase Pattern (glyph_atlas.v:116-212)
```v
// State Machine: load_glyph
//
// Normal Path (outline fonts):
//   FT_Load_Glyph (NO_BITMAP) -> FT_Outline_Translate -> FT_Render_Glyph
//
// Fast Path (no subpixel shift):
//   FT_Load_Glyph (RENDER) -> done
//
// Fallback Path (bitmap fonts):
//   FT_Load_Glyph (NO_BITMAP) -> FT_Render_Glyph fails ->
//   FT_Load_Glyph (RENDER) -> done

fn (mut renderer Renderer) load_glyph(cfg LoadGlyphConfig) !CachedGlyph {
    // ... flag setup ...

    // Requires: face valid, size set (Pango ensures this)
    if C.FT_Load_Glyph(cfg.face, cfg.index, flags) != 0 {
        return error('FT_Load_Glyph failed')
    }

    mut glyph := cfg.face.glyph

    if should_shift {
        // Requires: outline loaded (NO_BITMAP flag used)
        C.FT_Outline_Translate(&glyph.outline, shift, 0)

        // Requires: outline available for rendering
        if C.FT_Render_Glyph(glyph, render_mode) != 0 {
            // Fallback: bitmap font or outline-less glyph
            // Requires: same face validity
            if C.FT_Load_Glyph(...) != 0 {
                return error('fallback failed')
            }
        }
    }
    // ...
}
```

### Validated Debug Check Pattern (from Phase 4/5)
```v
// Source: layout.v:199-204, 818-821
$if debug {
    if iter_exhausted {
        panic('layout iterator reused after exhaustion')
    }
}
// Equivalent for FT state:
$if debug {
    if should_shift && glyph.outline.n_points == 0 {
        panic('Expected outline for translate, got empty. ' +
              'See: docs/ARCHITECTURE.md#freetype-state')
    }
}
```

### Error Message Format (matches Phase 4/5)
```v
// Pattern: "Expected [state], got [actual]. [pointer to docs]"
panic("Expected 'loaded' state for FT_Render_Glyph, got 'unloaded'. " +
      "See: glyph_atlas.v load->translate->render sequence")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Trust caller | Debug validation | Phase 4-6 hardening | Catches misuse early |
| Full state enum | Prerequisite checks | Design decision | Simpler, less overhead |
| External docs only | Inline + external | Industry standard | Better maintainability |

**Deprecated/outdated:**
- Complex state machine wrappers - FT API is already well-structured
- Runtime state tracking for release builds - zero overhead in prod per CONTEXT.md

## Open Questions

Things that couldn't be fully resolved:

1. **ASCII state diagram inclusion**
   - What we know: Three-state sequence (load->translate->render) is simple
   - What's unclear: Whether visual diagram adds value vs inline docs
   - Recommendation: Skip ASCII diagram; inline "Requires:" comments sufficient

2. **Fallback path state divergence**
   - What we know: Fallback reloads with FT_LOAD_RENDER, skips translate/render
   - What's unclear: Whether this is "different sequence" or "same invariants"
   - Recommendation: Document as alternative valid path; both paths produce bitmap

3. **Face validity checking**
   - What we know: Face comes from Pango, should always be valid
   - What's unclear: Whether to add nil check before FT operations
   - Recommendation: Check in debug only; Pango owns face lifecycle

## Sources

### Primary (HIGH confidence)
- [FreeType Glyph Retrieval](http://freetype.org/freetype2/docs/reference/ft2-glyph_retrieval.html)
  - FT_Load_Glyph prerequisites: "size must be meaningfully initialized"
  - FT_Render_Glyph: "slot must contain loaded glyph data"
- [FreeType Outline Processing](http://freetype.org/freetype2/docs/reference/ft2-outline_processing.html)
  - FT_Outline_Translate: operates on outline structure, void return
- [FreeType Tutorial Step 2](https://freetype.sourceforge.net/freetype2/docs/tutorial/step2.html)
  - "translate outline so lower left corner matches (0,0)"
- Existing codebase: glyph_atlas.v:116-212 - current load/translate/render pattern
- Existing codebase: layout.v:27-34, 199-204 - Phase 4/5 debug validation pattern

### Secondary (MEDIUM confidence)
- [FreeType Glyph Conventions](https://freetype.org/freetype2/docs/glyphs/glyphs-6.html)
  - Outline vs bitmap distinction
- V Language $if debug - conditional compilation for debug-only code

### Tertiary (LOW confidence)
- None - all findings verified with official FreeType docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - FreeType official docs + existing V patterns verified
- Architecture: HIGH - Current codebase already implements sequence correctly
- Pitfalls: HIGH - Verified via FreeType docs + codebase analysis

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable FreeType API, stable V language features)
