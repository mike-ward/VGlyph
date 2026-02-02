# Phase 4: Layout Iteration - Research

**Researched:** 2026-02-02
**Domain:** C iterator lifecycle, V defer patterns, resource RAII wrappers
**Confidence:** HIGH

## Summary

Researched safe iterator patterns for wrapping C library iterators (PangoLayoutIter) in V
language. Current code creates iterators, uses defer for cleanup, but lacks guards against
iterator reuse after exhaustion and lifecycle documentation.

PangoLayoutIter requires manual cleanup via `pango_layout_iter_free()`. Cannot be reused after
exhaustion - must create new iterator. V supports defer blocks for automatic cleanup and custom
iterator pattern via `next() ?T` method. Debug validation via `$if debug { panic() }` pattern.

**Primary recommendation:** Wrap PangoLayoutIter in V struct with defer cleanup, exhaustion
flag, inline lifecycle docs.

## Standard Stack

### Core Language Features
| Feature | Purpose | Why Standard |
|---------|---------|--------------|
| `defer { }` | Scope-exit cleanup | Built-in, executes on return/panic |
| `$if debug` | Debug-only checks | Conditional compilation, no runtime cost |
| `panic(msg)` | Fatal errors | Stack trace for validation failures |
| Custom iterator | V-style iteration | `next() ?T` pattern for optional values |

### Supporting
| Feature | Purpose | When to Use |
|---------|---------|-------------|
| Struct wrapper | Resource encapsulation | Hide C pointer, track state |
| Private fields | Prevent misuse | Enforce lifecycle through API |
| Method receiver | Cleanup API | `fn (mut it Iterator) free()` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| defer | Manual free calls | defer guarantees cleanup on all paths |
| Wrapper struct | Direct C calls | Wrapper enforces lifecycle rules |
| Exhaustion flag | Trust caller | Flag prevents undefined behavior |

**Installation:**
N/A - built-in language features

## Architecture Patterns

### Recommended Iterator Wrapper Structure
```v
struct LayoutIterator {
mut:
    iter      &C.PangoLayoutIter  // C iterator handle
    exhausted bool                 // Prevent reuse after end
}

fn new_layout_iterator(layout &C.PangoLayout) ?LayoutIterator {
    iter := C.pango_layout_get_iter(layout)
    if iter == unsafe { nil } {
        return none
    }
    return LayoutIterator{
        iter: iter
        exhausted: false
    }
}

fn (mut it LayoutIterator) free() {
    if voidptr(it.iter) != unsafe { nil } {
        C.pango_layout_iter_free(it.iter)
        it.iter = unsafe { nil }
    }
}
```

### Pattern 1: Defer-Based Automatic Cleanup
**What:** Defer cleanup immediately after resource acquisition
**When to use:** All C resource allocations requiring manual free
**Example:**
```v
// Source: https://www.rangakrish.com/index.php/2023/04/20/defer-statement-in-v-language/
fn process_layout(layout &C.PangoLayout) {
    iter := C.pango_layout_get_iter(layout)
    if iter == unsafe { nil } {
        return
    }
    defer { C.pango_layout_iter_free(iter) }

    // Use iter - cleanup guaranteed on all exit paths
}
```

### Pattern 2: Exhaustion Guard
**What:** Flag set when iteration completes, checked before reuse
**When to use:** Iterators that cannot be reset or reused
**Example:**
```v
fn (mut it LayoutIterator) next_run() ?&C.PangoLayoutRun {
    $if debug {
        if it.exhausted {
            panic('iterator already exhausted - create new iterator')
        }
    }

    run := C.pango_layout_iter_get_run_readonly(it.iter)
    if !C.pango_layout_iter_next_run(it.iter) {
        it.exhausted = true
    }
    return run
}
```

### Pattern 3: Inline Lifecycle Documentation
**What:** Comment at creation site documenting lifecycle rules
**When to use:** Complex C FFI resource patterns
**Example:**
```v
// Iterator lifecycle:
// 1. Create via new_layout_iterator() or C.pango_layout_get_iter()
// 2. Use with next_run()/next_char()/next_line() until exhausted
// 3. DO NOT reuse after exhausted - create new iterator
// 4. MUST call free() or use defer for cleanup
iter := C.pango_layout_get_iter(layout)
defer { C.pango_layout_iter_free(iter) }
```

### Anti-Patterns to Avoid
- **Reusing exhausted iterator:** Undefined behavior, may crash or loop forever
- **Manual free without defer:** Easy to miss on error paths, causes leaks
- **No exhaustion check:** Silent bugs in debug builds, crashes in production

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scope cleanup | try/finally | defer { } | Simpler, covers panic paths |
| Iterator protocol | Custom pattern | `next() ?T` | Standard V iterator interface |
| Debug validation | Custom flags | `$if debug { panic() }` | Zero runtime cost in production |
| Resource wrapper | Manual tracking | Struct + defer | Encapsulation + compiler enforcement |

**Key insight:** V's defer and conditional compilation eliminate need for complex RAII
class hierarchies - simple defer block at allocation site provides automatic cleanup.

## Common Pitfalls

### Pitfall 1: Iterator Reuse After Exhaustion
**What goes wrong:** Calling next_X() after iteration completes causes undefined behavior
**Why it happens:** Pango iterators don't reset, no built-in guard against reuse
**How to avoid:** Set exhausted flag on last iteration, check in debug builds
**Warning signs:** Infinite loops, crashes in iteration code, missing data

### Pitfall 2: Missing defer After Iterator Creation
**What goes wrong:** Exception/early return leaks iterator memory
**Why it happens:** Defer not placed immediately after allocation
**How to avoid:** Pattern: allocate, check nil, defer free
**Warning signs:** Growing memory usage, Valgrind reports PangoLayoutIter leaks

### Pitfall 3: Creating New Iterator in compute_lines
**What goes wrong:** Code comment says "iter might be at end" and creates new one
**Why it happens:** Misunderstanding - iterators cannot be reset
**How to avoid:** Always create fresh iterator when needed, document why
**Warning signs:** Comment explaining workaround instead of design

### Pitfall 4: No Lifecycle Documentation
**What goes wrong:** Developers unsure if iterator can be reused or must be freed
**Why it happens:** C FFI patterns not obvious to V developers
**How to avoid:** Inline comment at creation documenting full lifecycle
**Warning signs:** Questions about memory leaks or reuse safety

## Code Examples

Verified patterns from official sources and research:

### V Defer Statement (2023)
```v
// Source: https://www.rangakrish.com/index.php/2023/04/20/defer-statement-in-v-language/
fn write_trace(log_text string) {
    defer {
        file.write_string('\nEnd of trace\n') or { panic(err) }
        file.close()
    }
    file.write_string(log_text) or { panic(err) }
}
// defer executes on function return, not where lexically placed
```

### V Custom Iterator Pattern
```v
// Source: https://docs.vlang.io/statements-&-expressions.html
struct SquareIterator {
    arr []int
mut:
    idx int
}

fn (mut iter SquareIterator) next() ?int {
    if iter.idx >= iter.arr.len {
        return none
    }
    defer { iter.idx++ }
    return iter.arr[iter.idx] * iter.arr[iter.idx]
}
```

### Current Codebase Pattern
```v
// Source: layout.v:108-113
iter := C.pango_layout_get_iter(layout)
if iter == unsafe { nil } {
    return Layout{}
}
defer { C.pango_layout_iter_free(iter) }
// Good: defer immediately after allocation
// Missing: exhaustion guard, lifecycle docs
```

### Exhaustion Prevention (Python example translates to V)
```v
// Source: https://labex.io/tutorials/python-how-to-prevent-iterator-exhaustion-418963
// Pattern: Check hasNext before calling next
fn (mut it LayoutIterator) has_next() bool {
    return !it.exhausted
}

fn process_all() {
    for it.has_next() {
        item := it.next() or { break }
        // process item
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual try/finally | defer { } | V 0.1+ | Simpler cleanup, covers panic |
| RAII classes | Struct + defer | V 0.2+ | Less boilerplate, same safety |
| Runtime checks always | $if debug checks | V 0.3+ | Zero prod cost for validation |
| defer(fn){} for scoped | defer{} scoped by default | V 0.5 (Dec 2025) | More intuitive scope behavior |

**Deprecated/outdated:**
- defer(fn){} syntax - now defer{} is scoped by default (V 0.5)
- Trusting iterator safety without guards - modern practice adds debug validation

## Open Questions

Things that couldn't be fully resolved:

1. **PangoLayoutIter reuse behavior**
   - What we know: Cannot reset, must create new after exhaustion
   - What's unclear: Exact undefined behavior if next_X called after exhausted
   - Recommendation: Document as undefined, guard in debug builds

2. **Thread safety of PangoLayoutIter**
   - What we know: No thread safety mentioned in docs
   - What's unclear: If multiple threads can read same iterator
   - Recommendation: Document as not thread-safe (V is single-threaded by design anyway)

3. **Performance cost of exhaustion flag**
   - What we know: Single bool check per iteration
   - What's unclear: Impact on hot path with millions of glyphs
   - Recommendation: Debug-only check acceptable given prior decision on debug-only validation

## Sources

### Primary (HIGH confidence)
- [V Conditional Compilation](https://docs.vlang.io/conditional-compilation.html) - $if debug,
  compile-time conditionals
- [V Statements & Expressions](https://docs.vlang.io/statements-&-expressions.html) - Custom
  iterator pattern with next() ?T
- [V Defer Statement](https://www.rangakrish.com/index.php/2023/04/20/defer-statement-in-v-language/)
  - defer cleanup pattern
- [Pango LayoutIter](https://docs.gtk.org/Pango/struct.LayoutIter.html) -
  pango_layout_iter_free() required
- [Pango Layout.get_iter](https://docs.gtk.org/Pango/method.Layout.get_iter.html) - Caller owns
  returned iterator
- Existing codebase: layout.v:108-113, 733-737, 803-804 - current defer patterns

### Secondary (MEDIUM confidence)
- [RAII Best Practices](https://en.cppreference.com/w/cpp/language/raii.html) - Resource
  wrapper patterns
- [Iterator Exhaustion Prevention](https://labex.io/tutorials/python-how-to-prevent-iterator-exhaustion-418963)
  - hasNext pattern
- [V Struct Methods](https://docs.vlang.io/structs.html) - Method receivers

### Tertiary (LOW confidence)
- [V Changelog](https://github.com/vlang/v/blob/master/CHANGELOG.md) - defer{} scoped by
  default in v0.5
- Layout.v:800 comment about iterator reset - suggests reuse not possible

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official V docs + Pango docs + existing patterns
- Architecture: HIGH - Verified defer pattern in codebase, iterator pattern in V docs
- Pitfalls: MEDIUM - Inferred from code comments and general iterator patterns

**Research date:** 2026-02-02
**Valid until:** 2026-03-02 (30 days - stable V language features, stable Pango API)
