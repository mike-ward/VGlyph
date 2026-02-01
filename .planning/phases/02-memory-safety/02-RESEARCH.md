# Phase 2: Memory Safety - Research

**Researched:** 2026-02-01
**Domain:** V language memory allocation safety
**Confidence:** HIGH

## Summary

Researched V language memory safety patterns for validating vcalloc allocations. V's vcalloc
can return nil on allocation failure despite common belief it panics. Codebase already uses
null check pattern at lines 77, 446. Overflow detection via i64 arithmetic before allocation
prevents integer overflow in size calculations. Standard approach: check overflow with i64
multiplication, enforce reasonable limits (1GB), check vcalloc return for nil, return distinct
errors.

User decisions from CONTEXT.md constrain approach: return errors (not log), clean up partial
state on failure, extend error messages with location info, create shared helper for overflow
checks, distinct error types per cause.

**Primary recommendation:** Follow existing codebase pattern - i64 overflow check before
allocation, vcalloc nil check after, shared helper function for size validation.

## Standard Stack

V language builtin memory operations. No external libraries needed.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| builtin | V stdlib | vcalloc, vmemcpy, vmemset | Only memory allocation in V |
| builtin | V stdlib | unsafe blocks | Required for vcalloc, pointer ops |
| builtin | V stdlib | Result types (!T) | Standard error mechanism |

### Supporting
None needed - V builtin operations complete.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| vcalloc | malloc | vcalloc zeros memory, preventing visual artifacts |
| Result types | panic | Results allow caller recovery, matches Phase 1 |
| i64 overflow check | unchecked | i64 prevents overflow in intermediate calculation |

**Installation:**
None - builtin V language feature.

## Architecture Patterns

### Recommended Pattern Structure
```
1. Overflow check (i64 arithmetic)
2. Size limit check (reasonable max, e.g., 1GB)
3. vcalloc allocation
4. Nil check
5. Error return with location info
```

### Pattern 1: Overflow Detection Before Allocation
**What:** Use i64 for intermediate calculation, check against max_i32 before casting to int
**When to use:** Before any vcalloc where width * height * channels could overflow
**Example:**
```v
// Source: /Users/mike/Documents/github/vglyph/glyph_atlas.v:54-56
size := i64(w) * i64(h) * 4
if size <= 0 || size > max_i32 {
    return error('Atlas size overflow: ${w}x${h} = ${size} bytes')
}
```

### Pattern 2: Null Check After vcalloc
**What:** Check vcalloc return value against unsafe { nil } before dereferencing
**When to use:** After every vcalloc call
**Example:**
```v
// Source: /Users/mike/Documents/github/vglyph/glyph_atlas.v:76-79
img.data = unsafe { vcalloc(int(size)) }
if img.data == unsafe { nil } {
    return error('Failed to allocate atlas memory: ${size} bytes')
}
```

### Pattern 3: Shared Helper Function
**What:** Centralized validation for width * height calculations
**When to use:** Multiple vcalloc sites with similar overflow patterns
**Example:**
```v
// Proposed pattern based on user decision
fn check_allocation_size(w int, h int, channels int) !i64 {
    size := i64(w) * i64(h) * i64(channels)
    const max_allocation_size = i64(1024 * 1024 * 1024) // 1GB

    if size <= 0 {
        return error('Invalid allocation size: ${w}x${h}x${channels}')
    }
    if size > max_i32 {
        return error('Allocation size overflow: ${size} bytes')
    }
    if size > max_allocation_size {
        return error('Allocation size exceeds limit: ${size} bytes (max: ${max_allocation_size})')
    }
    return size
}
```

### Pattern 4: Partial State Cleanup
**What:** Free first allocation if second allocation fails
**When to use:** Functions with multiple allocations
**Example:**
```v
// Proposed pattern based on user decision
first_data := unsafe { vcalloc(size1) }
if first_data == unsafe { nil } {
    return error('First allocation failed')
}

second_data := unsafe { vcalloc(size2) }
if second_data == unsafe { nil } {
    unsafe { free(first_data) } // Clean up partial state
    return error('Second allocation failed')
}
```

### Pattern 5: Location-Aware Error Messages
**What:** Include function name or line info in error messages
**When to use:** Multiple vcalloc sites, helps debugging
**Example:**
```v
// Proposed pattern based on user decision
if new_data == unsafe { nil } {
    return error('allocation failed in resize_atlas: ${new_size} bytes')
}
```

### Anti-Patterns to Avoid
- **Don't assume vcalloc panics:** vcalloc can return nil, must check
- **Don't use int for size calculation:** int overflow undefined, use i64 then check bounds
- **Don't skip overflow check:** Even if allocation succeeds, overflow means wrong size
- **Don't check after dereference:** Check immediately after allocation

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Overflow detection | Custom multiply check | i64 arithmetic + bounds check | i64 prevents overflow, simple bounds check validates |
| nil checking | isnil() function | unsafe { nil } comparison | Direct comparison is codebase pattern (lines 77, 446) |
| Size limits | Magic numbers inline | Named constant | User decision: 1GB limit, should be documented constant |

**Key insight:** V's i64 type naturally prevents overflow in intermediate calculations.
Cast to i64 before multiply, check bounds, then cast to int for allocation.

## Common Pitfalls

### Pitfall 1: Assuming vcalloc Panics on Failure
**What goes wrong:** Code doesn't check vcalloc return, assumes it panics like docs suggest
**Why it happens:** V documentation unclear, claims "no null" but vcalloc can return nil
**How to avoid:** Always check vcalloc return value against unsafe { nil }
**Warning signs:** Codebase already does this at lines 77, 446 - pattern exists for reason

### Pitfall 2: Integer Overflow in Size Calculation
**What goes wrong:** width * height overflows before comparison, allocates wrong size
**Why it happens:** int overflow is undefined behavior in C (V compiles to C)
**How to avoid:** Cast to i64 before multiply: i64(w) * i64(h) * channels
**Warning signs:** Negative size values, unexpectedly small allocations

### Pitfall 3: Forgetting max_i32 Bound Check
**What goes wrong:** i64 size fits in i64 but not in int, truncated when cast
**Why it happens:** i64 range much larger than int (int is i32 on most platforms)
**How to avoid:** Check size > max_i32 before cast to int
**Warning signs:** Codebase pattern at lines 56, 221, 441 - all check max_i32

### Pitfall 4: Silent Failure in Mutating Methods
**What goes wrong:** grow() at line 430 returns void, can't propagate error
**Why it happens:** Function signature incompatible with error return
**How to avoid:** User decision: return error even from mutating methods, or change to !void
**Warning signs:** log.error at lines 441, 447 - currently can't return error

### Pitfall 5: Inconsistent Error Granularity
**What goes wrong:** Generic "allocation failed" doesn't distinguish overflow from OOM
**Why it happens:** Temptation to use single error message
**How to avoid:** User decision: distinct messages per cause (overflow, null, size limit)
**Warning signs:** Cannot diagnose root cause from error message alone

## Code Examples

Verified patterns from existing codebase:

### Overflow Check with i64 Arithmetic
```v
// Source: /Users/mike/Documents/github/vglyph/glyph_atlas.v:54-56
size := i64(w) * i64(h) * 4
if size <= 0 || size > max_i32 {
    return error('Atlas size overflow: ${w}x${h} = ${size} bytes')
}
```

### vcalloc Null Check in Constructor
```v
// Source: /Users/mike/Documents/github/vglyph/glyph_atlas.v:76-79
img.data = unsafe { vcalloc(int(size)) }
if img.data == unsafe { nil } {
    return error('Failed to allocate atlas memory: ${size} bytes')
}
```

### vcalloc Null Check in Mutating Method
```v
// Source: /Users/mike/Documents/github/vglyph/glyph_atlas.v:445-449
mut new_data := unsafe { vcalloc(int(new_size)) }
if new_data == unsafe { nil } {
    log.error('${@FILE_LINE}: Failed to allocate atlas memory: ${new_size} bytes')
    return
}
```

### Cleanup Pattern with unsafe free
```v
// Source: /Users/mike/Documents/github/vglyph/glyph_atlas.v:452-458
unsafe {
    vmemcpy(new_data, atlas.image.data, int(old_size))
    dest_ptr := &u8(new_data) + old_size
    vmemset(dest_ptr, 0, int(new_size - old_size))
    free(atlas.image.data)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No null checks | Check unsafe { nil } | Phase 1 (lines 77) | Allocation failure caught |
| No overflow checks | i64 arithmetic + bounds | Phase 1 (lines 54-56) | Integer overflow prevented |
| log.error in grow() | Return error | Phase 2 (planned) | Caller can handle failure |
| Generic errors | Location-specific | Phase 2 (planned) | Better debugging |

**Deprecated/outdated:**
- Assumption vcalloc always succeeds: Codebase evidence shows nil checks required
- int arithmetic for sizes: Overflow undefined behavior, i64 safer

## Open Questions

### Question 1: max_i32 Constant Definition
- What we know: Used at lines 56, 221, 441 but not defined in glyph_atlas.v
- What's unclear: Where is max_i32 defined? Is it V builtin or custom constant?
- Recommendation: Grep codebase for definition or define if missing

### Question 2: Mutating Method Return Types
- What we know: grow() returns void, can't return error currently
- What's unclear: Should grow() return !void or Result<void, Error>?
- Recommendation: User wants error propagation - change signature to fn grow() !

### Question 3: Size Limit Value
- What we know: User wants "reasonable limit (e.g., 1GB)"
- What's unclear: Exact limit? 1GB = 1024^3 or 1000^3?
- Recommendation: Use 1GB = 1024 * 1024 * 1024 (binary), document as constant

## Sources

### Primary (HIGH confidence)
- /Users/mike/Documents/github/vglyph/glyph_atlas.v (lines 54-79, 440-449)
- /Users/mike/Documents/github/vglyph/.planning/phases/01-error-propagation/01-RESEARCH.md
- /Users/mike/Documents/github/vglyph/.planning/phases/02-memory-safety/02-CONTEXT.md
- [V Documentation - Memory Unsafe Code](https://docs.vlang.io/memory-unsafe-code.html)
- [V modules.vlang.io - builtin](https://modules.vlang.io/builtin.html)

### Secondary (MEDIUM confidence)
- [V Documentation - Type Declarations](https://docs.vlang.io/type-declarations.html)
- [GitHub vlang/v - Issue #13990](https://github.com/vlang/v/issues/13990)
- [GitHub vlang/v - Issue #15117](https://github.com/vlang/v/issues/15117)

### Tertiary (LOW confidence)
- WebSearch results on vcalloc behavior (contradictory - docs say no null, code checks nil)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - V builtin, codebase already uses pattern
- Architecture: HIGH - Existing code at lines 54-79, 440-449 demonstrates pattern
- Pitfalls: HIGH - Based on codebase evidence and V/C overflow behavior
- Size limits: MEDIUM - User specified 1GB, exact constant needs clarification
- Mutating method signatures: MEDIUM - Signature change required, pattern TBD

**Research date:** 2026-02-01
**Valid until:** 90 days (V language stable, memory safety patterns unlikely to change)
