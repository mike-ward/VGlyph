# Phase 23: Code Consistency - Research

**Researched:** 2026-02-04
**Domain:** V language code audit/standardization
**Confidence:** HIGH

## Summary

Code consistency in V codebases centers on automated enforcement via `v fmt` and strict
adherence to V's official naming conventions. V intentionally provides a single, opinionated style
to eliminate bikeshedding - snake_case for functions/variables, PascalCase for types, lowercase
error messages without punctuation.

The vglyph codebase already follows V conventions closely, using `_test.v` naming, `!` error
returns, and proper doc comments. This audit focuses on verification and edge case cleanup rather
than wholesale refactoring.

**Primary recommendation:** Use `v fmt -verify` for automated verification, then manual audit for
naming consistency, error handling idioms, and doc comment completeness on all `pub fn`.

## Standard Stack

Core V tooling provides built-in consistency enforcement:

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| v fmt | Built-in | Automatic code formatting | Only formatter, enforces single style |
| v -check-syntax | Built-in | Syntax validation without compilation | Fast error detection |
| v -check | Built-in | Full semantic checking | Pre-compilation validation |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| grep/rg | Any | Pattern detection | Find naming inconsistencies |
| git diff | Any | Verify no changes after fmt | Prove formatting compliance |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| v fmt | Custom linter | V has no custom linters - fmt is authoritative |
| Manual review | AST analysis | V lacks mature AST tooling for style checks |

**Installation:**
```bash
# V compiler includes all tools
v version  # Verify V installed
```

## Architecture Patterns

### Audit Workflow Structure
```
1. Automated checks (v fmt -verify, v -check-syntax)
2. Pattern-based searches (grep for naming violations)
3. Manual review (doc comments, error handling consistency)
4. Incremental fixes (one category at a time)
```

### Pattern 1: Naming Convention Verification
**What:** Verify snake_case functions/variables, PascalCase types
**When to use:** Every V codebase consistency audit
**Example:**
```bash
# Find PascalCase in function names (violation)
rg '^(pub )?fn [A-Z]' --type v

# Find snake_case in type names (violation)
rg '^(pub )?struct [a-z]' --type v

# Constants - V allows both snake_case and SCREAMING_SNAKE_CASE
# Context: FreeType/C interop uses SCREAMING for C constants
rg '^pub const (ft_|FT_)' c_bindings.v  # Acceptable mixing for C FFI
```

### Pattern 2: Error Handling Audit
**What:** Verify `!` returns used, no bare panics, lowercase error messages
**When to use:** Security/robustness audits
**Example:**
```v
// CORRECT: Function returns ! for errors
pub fn new_text_system(mut gg_ctx gg.Context) !&TextSystem {
    tr_ctx := new_context(scale)!  // Propagate with !
    return error('null context')    // Lowercase, no period
}

// WRONG: Bare panic (convert to error return)
pub fn risky_operation() {
    panic('Something failed')  // Convert to: return error('something failed')
}
```

### Pattern 3: Doc Comment Coverage
**What:** All `pub fn` have doc comments starting with function name
**When to use:** Public API surface area
**Example:**
```v
// draw_text renders text string at (x, y) using configuration.
// Handles layout caching to optimize performance for repeated calls.
//
// Returns error if:
// - text is empty, exceeds max length (10KB), or contains invalid UTF-8
// - null context or renderer
pub fn (mut ts TextSystem) draw_text(x f32, y f32, text string, cfg TextConfig) ! {
```

### Pattern 4: File Organization
**What:** Logical file splits, platform-specific suffixes, test naming
**When to use:** File structure consistency
**Example:**
```
vglyph/
├── api.v                      # Public API (pub fn at top)
├── context.v                  # Core types
├── c_bindings.v               # C interop isolation
├── accessibility/             # Subsystem module
│   ├── backend_darwin.v       # Platform-specific (_darwin.v suffix)
│   └── backend_stub.v         # Default implementation
├── _api_test.v                # Test file (_test.v suffix)
└── examples/                  # Examples in top-level directory
    └── demo.v
```

### Anti-Patterns to Avoid
- **Mixed casing in module:** Using camelCase and snake_case inconsistently
- **Verbose doc boilerplate:** V doc comments should be terse, not javadoc-style
- **Panic for recoverable errors:** Convert to `!` returns unless truly unrecoverable
- **Missing error docs:** "Returns error if:" section should list all error conditions

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Code formatting | Custom formatter/linter | v fmt | Single source of truth, no config |
| Style checking | AST walker for naming | Grep patterns + manual review | V lacks AST tooling |
| Test discovery | Custom test runner | v test (finds _test.v) | Built-in convention |
| Platform conditionals | #ifdef-like macros | _darwin.v / _linux.v files | V's file-level conditional compilation |

**Key insight:** V intentionally minimizes tooling choices. Use what's built-in.

## Common Pitfalls

### Pitfall 1: Assuming v fmt handles naming
**What goes wrong:** v fmt only formats whitespace/style, not naming violations
**Why it happens:** Other languages have linters that enforce naming (clippy, golangci-lint)
**How to avoid:** Manual grep for PascalCase functions, snake_case types
**Warning signs:** Mixed casing across modules despite passing v fmt

### Pitfall 2: Over-using panic
**What goes wrong:** Functions panic instead of returning errors, can't test error paths
**Why it happens:** panic is easier than adding ! return type and propagation
**How to avoid:** Grep for `panic(`, audit if each is truly unrecoverable
**Warning signs:** Panic in library code (not main/examples), untestable error conditions

### Pitfall 3: Inconsistent error message format
**What goes wrong:** Mixed "Error: xyz." vs "xyz" vs capitalized messages
**Why it happens:** No compiler enforcement of error message style
**How to avoid:** Grep error() calls, verify lowercase and no trailing punctuation
**Warning signs:** Error logs show mixed capitalization

### Pitfall 4: Wrong test file naming
**What goes wrong:** Test files named test_api.v instead of _api_test.v, not discovered
**Why it happens:** Different languages use different conventions (test_*.py, *_test.go)
**How to avoid:** V requires _test.v suffix - verify with `find . -name '*test*.v'`
**Warning signs:** Tests exist but `v test .` doesn't run them

### Pitfall 5: Platform file suffix confusion
**What goes wrong:** Using _darwin.v instead of required _darwin.c.v for C interop
**Why it happens:** Documentation shows both patterns, unclear when each applies
**How to avoid:** Use _darwin.c.v for files with C code, _darwin.v for pure V conditional
**Warning signs:** Platform-specific code compiles on wrong platform

### Pitfall 6: Abbreviation casing inconsistency
**What goes wrong:** utf8 in one place, UTF8 in another (same for http/HTTP, url/URL)
**Why it happens:** V doesn't enforce abbreviation casing, context-dependent
**How to avoid:** Pick convention per abbreviation, document in style guide
**Warning signs:** Same abbreviation appears with different casing

### Pitfall 7: Missing doc comments on pub fn
**What goes wrong:** Public functions lack doc comments, poor generated docs
**Why it happens:** V doesn't error on missing docs (unlike Rust #![deny(missing_docs)])
**How to avoid:** Grep for pub fn, verify preceding // comment exists
**Warning signs:** vdoc output has blank entries

### Pitfall 8: Line length exceeds limit
**What goes wrong:** Lines exceed 99 characters (project requirement), fail validation
**Why it happens:** v fmt wraps at 100, but project uses 99 for markdown consistency
**How to avoid:** Manual check after v fmt, use line length validator
**Warning signs:** Validation tool (v check-md -w) reports line length errors

## Code Examples

Verified patterns from official sources and vglyph codebase:

### Naming Conventions
```v
// Source: https://github.com/vlang/v/blob/master/doc/docs.md

// CORRECT: snake_case function, PascalCase type
pub fn new_text_system(mut gg_ctx gg.Context) !&TextSystem {
    return &TextSystem{}
}

// CORRECT: snake_case module-level constant
const max_text_length = 10240

// CORRECT: SCREAMING_SNAKE_CASE for C FFI constants (c_bindings.v)
pub const ft_load_default = 0
pub const ft_pixel_mode_gray = 2

// WRONG: PascalCase function
pub fn NewTextSystem() !&TextSystem { }  // Should be new_text_system

// WRONG: snake_case type
struct text_system { }  // Should be TextSystem
```

### Error Handling
```v
// Source: https://docs.vlang.io/type-declarations.html

// CORRECT: ! return type, lowercase error, no punctuation
pub fn validate_dimension(dim int, name string, caller_fn string) ! {
    if dim <= 0 {
        return error('${name} must be positive')
    }
}

// CORRECT: Error propagation with !
pub fn outer() ! {
    inner()!  // Propagate error upward
}

// WRONG: Bare panic (should return error)
pub fn validate(x int) {
    if x < 0 {
        panic('Invalid value')  // Convert to error return
    }
}

// WRONG: Capitalized error message
return error('Invalid input.')  // Should be: 'invalid input' (no period)
```

### Doc Comments
```v
// Source: https://docs.vlang.io/writing-documentation.html

// CORRECT: Comment starts with function name, terse, present tense
// draw_text renders text string at (x, y) using configuration.
//
// Returns error if:
// - text is empty or exceeds max length
pub fn (mut ts TextSystem) draw_text(x f32, y f32, text string) ! {
}

// CORRECT: Module-level doc (after module declaration)
module vglyph

// vglyph provides text layout and rendering using Pango/FreeType.
// It handles complex text shaping, bidirectional text, and font fallback.

// WRONG: Verbose boilerplate
// Function: draw_text
// Purpose: This function draws text on the screen
// Parameters:
//   - x: X coordinate (f32)
//   - y: Y coordinate (f32)
```

### Platform-Specific Files
```v
// Source: https://docs.vlang.io/conditional-compilation.html

// File: backend_darwin.v (pure V, platform-specific)
module accessibility

// macOS-specific implementation
pub fn platform_announce(text string) {
    // macOS NSAccessibility API calls
}

// File: ime_bridge_darwin.c.v (C interop, platform-specific)
#flag darwin -framework Cocoa
#include "ime_bridge.h"

// Must use .c.v suffix for C code
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Optional types (?) | Result types (!) | V 0.3+ (2021) | ! is preferred for errors |
| Triple-slash doc (///) | Double-slash (//) | Always | V uses // not /// |
| vfmt command | v fmt | V 0.2+ | Renamed to match v tool namespace |
| Manual formatting | v fmt on save | Current | Eliminates style debates |

**Deprecated/outdated:**
- `?Type` for errors: Use `!Type` for Result types (? still valid for Option/none)
- Separate vfmt binary: Use `v fmt` subcommand
- Custom linters: V philosophy is single style via v fmt

## Open Questions

1. **Abbreviation casing policy**
   - What we know: V allows both utf8 and UTF8, context-dependent
   - What's unclear: Whether to standardize per-project or follow stdlib per-case
   - Recommendation: Follow stdlib usage when importing (match their casing), pick
     consistent casing for internal abbreviations (document in STATE.md)

2. **Constant casing for C FFI**
   - What we know: V constants are snake_case, but C constants traditionally SCREAMING
   - What's unclear: Whether to normalize to snake_case or preserve C convention
   - Recommendation: Keep SCREAMING_SNAKE_CASE for C constants (ft_*, FT_*) to match C
     headers, use snake_case for pure V constants (max_text_length)

3. **Line length: 99 vs 100**
   - What we know: v fmt wraps at 100, project requires 99
   - What's unclear: How to enforce 99 without breaking v fmt
   - Recommendation: Run v fmt first (100 limit), then manual check for 99 violations,
     wrap manually if needed (rare, mostly comments)

4. **Test file location: _test.v pattern**
   - What we know: Codebase uses _test.v suffix (CON-05 requirement)
   - What's unclear: Whether this is V's standard or project-specific choice
   - Recommendation: Verify V docs for test file naming, confirm _test.v is canonical
     (WebSearch found both _test.v and test_*.v examples)

## Sources

### Primary (HIGH confidence)
- [V official docs - v fmt](https://docs.vlang.io/tools.html) - Formatting tool usage
- [V official docs - naming](https://github.com/vlang/v/blob/master/doc/docs.md) - snake_case
  vs PascalCase rules
- [V official docs - error handling](https://docs.vlang.io/type-declarations.html) - ! return
  types
- [V official docs - doc comments](https://docs.vlang.io/writing-documentation.html) - //
  comment format
- [V official docs - conditional compilation](https://docs.vlang.io/conditional-compilation.html)
  - Platform-specific file naming
- [V official docs - testing](https://docs.vlang.io/testing.html) - _test.v convention
- vglyph codebase review - Actual patterns used

### Secondary (MEDIUM confidence)
- [V GitHub discussions - panic vs error](https://github.com/vlang/v/discussions/15180) -
  Community guidance on error handling
- [V GitHub discussions - error() & panic()](https://github.com/vlang/v/issues/2030) - When to
  use each
- [V blog - unit tests](https://blog.vlang.io/elevate-your-v-project-with-unit-tests/) - Test
  file naming
- [V GitHub issue - v -check-syntax](https://github.com/vlang/v/issues/17191) - Syntax checking

### Tertiary (LOW confidence)
- General programming style guides - Principles only, not V-specific
- Code review checklists (Codacy, Swimm) - Generic patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - V's built-in tools are well-documented
- Architecture: HIGH - Audit patterns are straightforward, vglyph already follows conventions
- Pitfalls: HIGH - Common V mistakes documented in GitHub issues, confirmed in codebase

**Research date:** 2026-02-04
**Valid until:** 90 days (V is stable, style conventions change slowly)
