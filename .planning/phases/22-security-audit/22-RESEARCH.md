# Phase 22: Security Audit - Research

**Researched:** 2026-02-04
**Domain:** Defensive coding for C library wrappers in V language
**Confidence:** HIGH

## Summary

Security audit for VGlyph text rendering library wrapping FreeType, Pango, and HarfBuzz. Primary
threat model: untrusted text content from users. V provides strong safety defaults (bounds
checking, result types) but requires disciplined FFI handling. Recent FreeType CVE-2025-27363
demonstrates font library vulnerabilities remain active exploitation targets.

Standard approach: systematic audit of 11 security requirements covering input validation (UTF-8,
paths, numeric bounds), error handling (descriptive errors with source location), and resource
cleanup (FreeType/Pango object lifecycle). V's result types (`!`) enforce error handling but lack
built-in error chaining—requires custom wrapping.

**Primary recommendation:** Audit all C FFI boundaries first (highest risk), add V's
`encoding.utf8.validate` to all text inputs, wrap library errors with context, verify resource
cleanup on all error paths with defer statements.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| encoding.utf8.validate | V stdlib | UTF-8 validation | Native V module, HIGH confidence validation |
| V result types (`!`) | V language | Error handling | Language-level enforcement, cannot be unhandled |
| `defer` statement | V language | Resource cleanup | Guaranteed execution on scope exit |
| `@[direct_array_access]` | V attribute | Bounds check control | Performance vs safety tradeoff |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `log` module | V stdlib | Error logging | Development, debugging (already in use) |
| V's `or` blocks | V language | Error propagation | All result type handling |
| `$if debug` | V compile flag | Leak tracking | Resource lifecycle verification |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| V result types | Custom error struct | More flexibility but loses language enforcement |
| encoding.utf8 | Manual validation | Faster but reimplements security-critical code |
| defer | Manual cleanup | More control but error-prone (easily miss paths) |

**Installation:**
All features are V language built-ins or stdlib. No external packages needed.

## Architecture Patterns

### Recommended Audit Structure
```
Security Audit Flow:
1. Input Validation Layer (API boundary)
   - UTF-8 validation (encoding.utf8.validate.utf8_string)
   - Length/size limits (DoS prevention)
   - Null checks (public API entry points)

2. C FFI Boundary (C library calls)
   - Null pointer checks before dereference
   - Error code checking (FreeType error codes)
   - Bounds validation (array indices, sizes)

3. Resource Cleanup (all error paths)
   - defer for guaranteed cleanup
   - Track allocations in debug builds
   - Verify cleanup on early returns
```

### Pattern 1: UTF-8 Input Validation
**What:** Validate all user text before processing
**When to use:** Every public API accepting string input
**Example:**
```v
// Source: https://modules.vlang.io/encoding.utf8.validate.html
import encoding.utf8.validate

pub fn (mut ts TextSystem) draw_text(x f32, y f32, text string, cfg TextConfig) ! {
    // Validate UTF-8 encoding
    if !utf8.validate.utf8_string(text) {
        return error('Invalid UTF-8 encoding in text at ${@FILE}:${@LINE}')
    }

    // Length limit (DoS prevention)
    if text.len > max_text_length {
        return error('Text exceeds maximum length ${max_text_length} bytes at ${@FILE}:${@LINE}')
    }

    // Empty string explicit rejection
    if text.len == 0 {
        return error('Empty string not allowed at ${@FILE}:${@LINE}')
    }

    // Continue with processing...
}
```

### Pattern 2: C Library Error Wrapping
**What:** Wrap all C library errors with V context
**When to use:** Every FreeType, Pango, HarfBuzz call
**Example:**
```v
// Source: Defensive Coding Guide pattern
fn load_font(path string) !&C.FT_FaceRec {
    mut face := &C.FT_FaceRec(unsafe { nil })
    error_code := C.FT_New_Face(ft_library, path.str, 0, &face)

    if error_code != 0 {
        return error('FreeType error ${error_code} loading font "${path}" at ${@FILE}:${@LINE}')
    }

    if face == unsafe { nil } {
        return error('FT_New_Face returned null face for "${path}" at ${@FILE}:${@LINE}')
    }

    return face
}
```

### Pattern 3: Resource Cleanup with Defer
**What:** Guarantee cleanup on all exit paths
**When to use:** Any function allocating C resources
**Example:**
```v
// Source: Existing codebase pattern (layout.v:80)
pub fn (mut ctx Context) layout_text(text string, cfg TextConfig) !Layout {
    layout := setup_pango_layout(mut ctx, text, cfg)!
    defer { C.g_object_unref(layout) }  // Guaranteed cleanup

    // Early return still calls defer
    if some_error_condition {
        return error('...')  // defer executes before return
    }

    return build_layout_from_pango(layout, text, ctx.scale_factor, cfg)
}
```

### Pattern 4: Numeric Bounds Checking
**What:** Validate numeric parameters against valid ranges
**When to use:** Size, position, index parameters
**Example:**
```v
fn check_allocation_size(w int, h int, channels int, location string) !i64 {
    // Existing pattern from glyph_atlas.v:27
    size := i64(w) * i64(h) * i64(channels)

    if w <= 0 || h <= 0 || channels <= 0 {
        return error('Invalid allocation size in ${location}: ${w}x${h}x${channels} at ${@FILE}:${@LINE}')
    }

    if size > math.max_i32 {
        return error('Allocation overflow in ${location}: ${size} bytes exceeds max_i32 at ${@FILE}:${@LINE}')
    }

    if size > 1_000_000_000 {  // 1GB limit
        return error('Allocation exceeds 1GB limit in ${location}: ${size} bytes at ${@FILE}:${@LINE}')
    }

    return size
}
```

### Anti-Patterns to Avoid
- **Silent failures:** Never return without error on validation failure
- **Unsafe unwrapping:** Avoid `or { panic(err) }` in library code (use `!` propagation)
- **Missing defer:** Resource allocation without defer statement
- **Trusting C:** Assuming C library validates—always check return values
- **Generic errors:** `return error('failed')` without context (file, line, values)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UTF-8 validation | Byte-by-byte state machine | `encoding.utf8.validate` | Security-critical, optimized, tested |
| Error chaining | String concatenation | Custom IError impl with context | Type-safe, structured |
| Resource tracking | Manual counters | `$if debug` + global counters | Compile-time optional, zero runtime cost |
| Bounds checking | Manual if statements | V's default bounds checks | Language-enforced, can opt-out with `@[direct_array_access]` |
| Path sanitization | String manipulation | OS-specific validators | Path traversal attacks complex |

**Key insight:** UTF-8 validation appears simple (check byte patterns) but has subtle edge cases
(overlong encodings, surrogate pairs, invalid sequences). FreeType CVE-2025-27363 shows font
parsing remains active exploitation vector—don't parse font internals, let FreeType handle.

## Common Pitfalls

### Pitfall 1: Missing Error Context
**What goes wrong:** Error messages like "Invalid input" without details
**Why it happens:** Easy to write `return error('failed')` without context
**How to avoid:** Always include `${@FILE}:${@LINE}` and relevant parameter values
**Warning signs:** User bug reports say "it failed" but can't identify cause

### Pitfall 2: C Null Pointer Assumptions
**What goes wrong:** Segfault when C library returns null on error
**Why it happens:** V's safety doesn't extend to C FFI boundary
**How to avoid:** Check for `unsafe { nil }` on every C pointer return
**Warning signs:** Crashes only occur with invalid inputs (not caught by tests)

### Pitfall 3: Incomplete Resource Cleanup
**What goes wrong:** Memory leaks in error paths
**Why it happens:** Early returns bypass cleanup code
**How to avoid:** Use `defer` immediately after allocation
**Warning signs:** Memory usage grows over time, worse with errors

### Pitfall 4: Unicode Variation Selector DoS
**What goes wrong:** Attacker sends large text with variation selectors, exhausts memory
**Why it happens:** CVE-2025-12758—variation selectors pass length checks but expand memory
**How to avoid:** Enforce byte-length limits before processing, not character-length
**Warning signs:** High memory usage with "small" text inputs

### Pitfall 5: FreeType Error Code Ignorance
**What goes wrong:** Font loading fails silently or with generic error
**Why it happens:** FreeType returns error codes, not exceptions
**How to avoid:** Check every FreeType function return, wrap with context
**Warning signs:** Fonts don't load but no helpful error message

### Pitfall 6: Defer Scope Confusion
**What goes wrong:** Resource freed too early or too late
**Why it happens:** Defer executes at end of current scope, not function
**How to avoid:** Place defer immediately after allocation in same scope
**Warning signs:** Use-after-free or double-free in complex functions

## Code Examples

Verified patterns from official sources:

### Example 1: UTF-8 Validation
```v
// Source: https://modules.vlang.io/encoding.utf8.validate.html
import encoding.utf8.validate

fn validate_user_text(text string) !string {
    if !utf8.validate.utf8_string(text) {
        // Find approximate error location for debugging
        for i, b in text.bytes() {
            if !is_valid_utf8_byte_sequence(text[i..]) {
                return error('Invalid UTF-8 at byte ${i} in input at ${@FILE}:${@LINE}')
            }
        }
        return error('Invalid UTF-8 encoding in input at ${@FILE}:${@LINE}')
    }
    return text
}
```

### Example 2: V Result Type Error Handling
```v
// Source: V documentation error handling patterns
pub fn process_text(text string) !Layout {
    // Propagate errors with !
    validated := validate_user_text(text)!

    // Alternative: handle with or block
    layout := create_layout(validated) or {
        return error('Failed to create layout: ${err.msg()} at ${@FILE}:${@LINE}')
    }

    return layout
}
```

### Example 3: Resource Cleanup Tracking
```v
// Source: Existing pattern from layout.v:22-46
$if debug {
    __global resource_alloc_count = int(0)
}

fn track_resource_alloc() {
    $if debug {
        resource_alloc_count++
    }
}

fn track_resource_free() {
    $if debug {
        resource_alloc_count--
    }
}

pub fn check_resource_leaks() {
    $if debug {
        if resource_alloc_count != 0 {
            panic('Resource leak: ${resource_alloc_count} resource(s) not freed')
        }
    }
}
```

### Example 4: Bounds Checking with Context
```v
// Source: Existing pattern from glyph_atlas.v:27
fn validate_dimensions(w int, h int, location string) ! {
    if w <= 0 || h <= 0 {
        return error('Invalid dimensions in ${location}: ${w}x${h} at ${@FILE}:${@LINE}')
    }

    if w > max_texture_size || h > max_texture_size {
        return error('Dimensions exceed max texture size ${max_texture_size} in ${location}: ${w}x${h} at ${@FILE}:${@LINE}')
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual UTF-8 validation | `encoding.utf8.validate` | V stdlib addition | Use official module, don't hand-roll |
| Panic on errors | Result types (`!`) | V language design | Errors must be handled, enforced by compiler |
| Manual resource cleanup | `defer` statement | V language feature | Guaranteed cleanup on all exit paths |
| Try/catch exceptions | `or` blocks | V language design | Errors are values, explicit handling |
| Silent bounds violations | Default bounds checking | V default (can opt-out) | Safety by default, performance escape hatch |

**Deprecated/outdated:**
- String concatenation for error messages: Use format strings with context
- Global error state: Use result types to propagate errors
- Manual null checks everywhere: V's `?Type` optional types (but still needed for C FFI)

**Recent threats (2025-2026):**
- CVE-2025-27363: FreeType out-of-bounds write in font parsing (CVSS 8.1)
- CVE-2025-12758: Unicode variation selectors DoS attack
- General trend: Font libraries remain high-value targets for exploitation

## Open Questions

Things that couldn't be fully resolved:

1. **Exact DoS limits for text length, font size**
   - What we know: Industry uses varied limits (2000-10000 chars), depends on use case
   - What's unclear: Optimal values for VGlyph's use case
   - Recommendation: Start conservative (10KB text, 500pt max font), measure performance, adjust

2. **Error chain implementation approach**
   - What we know: V result types don't support built-in error chaining
   - What's unclear: Whether to implement custom IError with cause field or string wrapping
   - Recommendation: String wrapping sufficient for audit phase, defer custom IError to future

3. **Path sanitization on macOS**
   - What we know: Need to prevent path traversal, check file existence
   - What's unclear: Optimal V idioms for path validation (stdlib path module capabilities)
   - Recommendation: Use basic checks (no "..", absolute path), let FreeType validate format

4. **Pango object lifecycle edge cases**
   - What we know: Pango uses GObject reference counting
   - What's unclear: All edge cases where refs might leak (complex error paths)
   - Recommendation: Audit all `C.pango_*` calls, verify unref on all paths with grep

## Sources

### Primary (HIGH confidence)
- [V UTF-8 validation module](https://modules.vlang.io/encoding.utf8.validate.html) - Official V stdlib docs
- [V performance tuning](https://docs.vlang.io/performance-tuning.html) - Bounds checking control
- [V error handling](http://docs.vosca.dev/concepts/error-handling/overview.html) - Result type patterns

### Secondary (MEDIUM confidence)
- [CVE-2025-27363 FreeType vulnerability](https://thehackernews.com/2025/03/meta-warns-of-freetype-vulnerability.html) - Active exploitation
- [CVE-2025-12758 Unicode DoS](https://seclists.org/fulldisclosure/2026/Jan/27) - Variation selector attack
- [Red Hat Defensive Coding Guide](https://redhat-crypto.gitlab.io/defensive-coding-guide/) - C wrapper patterns
- [Secure Code Review Checklist](https://github.com/softwaresecured/secure-code-review-checklist) - Audit categories
- [OWASP Denial of Service](https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html) - DoS prevention

### Tertiary (LOW confidence)
- [WebSearch: Input validation practices 2026](https://www.securityjourney.com/post/why-input-validation-is-crucial-for-secure-coding-training) - General guidance
- [WebSearch: V language discussion](https://github.com/vlang/v/blob/master/doc/docs.md) - Community patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - V stdlib features, language built-ins
- Architecture: HIGH - Patterns verified in existing codebase, official docs
- Pitfalls: HIGH - Based on real CVEs and V FFI characteristics
- DoS limits: MEDIUM - Industry practices vary, need project-specific tuning

**Research date:** 2026-02-04
**Valid until:** 2026-03-04 (30 days—stable domain, but security landscape evolves)
