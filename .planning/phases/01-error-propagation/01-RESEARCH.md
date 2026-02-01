# Phase 1: Error Propagation - Research

**Researched:** 2026-02-01
**Domain:** V language error handling
**Confidence:** HIGH

## Summary

Researched V language error handling patterns for converting asserts to proper error returns.
V uses Result types (`!Type`) for error handling with mandatory `or` blocks for consumption.
Standard approach: change function return to `!GlyphAtlas`, replace asserts with
`return error('msg')`, update callers with `or` blocks.

Codebase already has 40+ functions using Result types consistently. All callers use `or { panic(err) }`
or `or { return }` patterns. No custom error types needed - builtin error() sufficient.

**Primary recommendation:** Follow existing codebase patterns - Result type + error() + or blocks.

## Standard Stack

V language builtin error handling. No external libraries needed.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| builtin | V stdlib | error(), Result types | Only error mechanism in V |

### Supporting
None needed - V builtin error handling is complete.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Result types | assert/panic | Asserts crash, can't be caught by callers |
| Result types | Custom IError | Unnecessary complexity for simple error messages |
| Result types | Option types (?T) | Options for none/value, Results for errors |

**Installation:**
None - builtin V language feature.

## Architecture Patterns

### Pattern 1: Function Declaration
**What:** Change return type from `T` to `!T`
**When to use:** When function can fail
**Example:**
```v
// Source: /Users/mike/Documents/github/vglyph/glyph_atlas.v
// Before:
fn new_glyph_atlas(mut ctx gg.Context, w int, h int) GlyphAtlas

// After:
fn new_glyph_atlas(mut ctx gg.Context, w int, h int) !GlyphAtlas
```

### Pattern 2: Error Returns
**What:** Replace assert with `return error('message')`
**When to use:** Instead of asserts that validate inputs or check allocation
**Example:**
```v
// Source: https://github.com/vlang/v/blob/master/doc/docs.md
// Before:
assert w > 0 && h > 0, 'Atlas dimensions must be positive: ${w}x${h}'

// After:
if w <= 0 || h <= 0 {
    return error('Atlas dimensions must be positive: ${w}x${h}')
}
```

### Pattern 3: Error Propagation
**What:** Use `!` operator to propagate errors up call stack
**When to use:** When calling Result-returning function and want to pass error to caller
**Example:**
```v
// Source: https://docs.vlang.io/type-declarations.html
fn f(url string) !string {
    resp := http.get(url)!  // Propagates error upward
    return resp.body
}
```

### Pattern 4: Error Handling with or Blocks
**What:** Use `or { }` block to handle errors at call site
**When to use:** When consuming Result-returning functions
**Example:**
```v
// Source: /Users/mike/Documents/github/vglyph/renderer.v (existing patterns)
// Pattern 1: Panic on error (init code)
mut atlas := new_glyph_atlas(mut ctx, 1024, 1024) or { panic(err) }

// Pattern 2: Return on error (recoverable)
cg := renderer.get_or_load_glyph(item, glyph, bin) or { return }

// Pattern 3: Default value on error
cg := renderer.get_or_load_glyph(item, glyph, 0) or { CachedGlyph{} }
```

### Anti-Patterns to Avoid
- **Don't ignore errors:** V compiler enforces `or` blocks - cannot compile without handling
- **Don't use assert for recoverable errors:** Asserts crash program, Result types allow recovery
- **Don't check allocation with assert:** Allocation failure should return error, not crash

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Error wrapping | Custom error struct | builtin error() | V has no try/catch, error() sufficient |
| Error types | IError interface impl | error() with message | Overhead unnecessary for simple errors |
| Nil checks | Custom validation | error() return | Consistent with V stdlib pattern |

**Key insight:** V's error handling is intentionally minimal. Custom error types add complexity
without value for this use case. String error messages via error() are idiomatic.

## Common Pitfalls

### Pitfall 1: Forgetting to Update Return Type
**What goes wrong:** Change error handling but forget `!` on return type
**Why it happens:** Easy to focus on function body, miss signature
**How to avoid:** Always update signature first, then body
**Warning signs:** Compiler error "cannot use error() in non-result function"

### Pitfall 2: Mixing Option and Result Types
**What goes wrong:** Using `?T` instead of `!T` for errors
**Why it happens:** Both use similar syntax, easy to confuse
**How to avoid:** `?T` = value or none, `!T` = value or error. Use `!` for errors.
**Warning signs:** Compiler wants `none` instead of `error()`

### Pitfall 3: Allocation Failure Handling
**What goes wrong:** Assuming vcalloc can return nil and check it
**Why it happens:** C pattern of checking malloc() return value
**How to avoid:** V's vcalloc aborts on failure by default. Use error return BEFORE allocation.
**Warning signs:** assert after vcalloc won't help - allocation already succeeded or aborted

### Pitfall 4: Over-Engineering Error Messages
**What goes wrong:** Creating complex error types/hierarchies
**Why it happens:** Experience with Java/Rust exception systems
**How to avoid:** Follow V philosophy - simple string messages via error()
**Warning signs:** Creating IError implementations, custom error structs

## Code Examples

Verified patterns from existing codebase:

### Constructor with Error Return
```v
// Source: /Users/mike/Documents/github/vglyph/context.v:23
pub fn new_context(scale_factor f32) !&Context {
    mut ft_lib := &C.FT_Library(unsafe { nil })
    if C.FT_Init_FreeType(&ft_lib) != 0 {
        return error('Failed to initialize FreeType library')
    }
    // ... rest of function
}
```

### Validation with Error Return
```v
// Source: /Users/mike/Documents/github/vglyph/glyph_atlas.v:203
pub fn ft_bitmap_to_bitmap(bmp &C.FT_Bitmap, ft_face &C.FT_FaceRec, target_height int) !Bitmap {
    if bmp.buffer == 0 || bmp.width == 0 || bmp.rows == 0 {
        return error('Empty bitmap')
    }
    // ... rest of function
}
```

### Overflow Check with Error Return
```v
// Source: /Users/mike/Documents/github/vglyph/glyph_atlas.v:214
out_length := i64(width) * i64(height) * i64(channels)
if out_length > max_i32 || out_length <= 0 {
    return error('Bitmap size overflow: ${width}x${height}')
}
```

### Caller Handling - Panic in Init
```v
// Source: /Users/mike/Documents/github/vglyph/examples/api_demo.v:35
app.ts = vglyph.new_text_system(mut app.ctx) or { panic(err) }
```

### Caller Handling - Return on Error
```v
// Source: /Users/mike/Documents/github/vglyph/renderer.v:142
cg := renderer.get_or_load_glyph(item, glyph, bin) or {
    CachedGlyph{} // fallback blank glyph
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Asserts | Result types | V language design | Errors can be handled by callers |
| Panic on error | or blocks | V language design | Graceful degradation possible |
| Exception handling | Result types | V language design | No try/catch needed |

**Deprecated/outdated:**
- assert for validation: V philosophy prefers recoverable errors
- panic() everywhere: Use Result types, let caller decide panic vs recover

## Open Questions

None. V error handling patterns are well-established and codebase already uses them consistently.

## Sources

### Primary (HIGH confidence)
- [V Documentation - Type Declarations](https://docs.vlang.io/type-declarations.html)
- [V GitHub Documentation](https://github.com/vlang/v/blob/master/doc/docs.md)
- /Users/mike/Documents/github/vglyph/glyph_atlas.v (existing patterns)
- /Users/mike/Documents/github/vglyph/renderer.v (existing callers)
- /Users/mike/Documents/github/vglyph/context.v (existing patterns)

### Secondary (MEDIUM confidence)
- None needed - official docs + codebase sufficient

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - V builtin, no alternatives
- Architecture: HIGH - Codebase has 40+ existing examples
- Pitfalls: HIGH - Based on V documentation and common mistakes

**Research date:** 2026-02-01
**Valid until:** 90 days (V language stable, unlikely to change error handling)
