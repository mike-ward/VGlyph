# Testing Patterns

**Analysis Date:** 2026-02-01

## Test Framework

**Runner:**
- Built-in V test runner (`v test .`)
- No external test framework dependency

**Assertion Library:**
- V's built-in `assert` statement

**Run Commands:**
```bash
v test .                    # Run all tests
v test -v .                 # Run all tests with verbose output
v _api_test.v              # Run specific test file
```

## Test File Organization

**Location:**
- Co-located with source code in same directory
- Tests live in root package directory alongside source files

**Naming:**
- Leading underscore prefix: `_api_test.v`, `_layout_test.v`, `_font_height_test.v`
- Pattern: `_[module_name]_test.v` (e.g., `_text_height_test.v` tests text height functionality)

**Structure:**
```
vglyph/
├── api.v
├── _api_test.v              # Tests for api.v
├── layout.v
├── _layout_test.v           # Tests for layout.v
├── context.v
├── _font_height_test.v      # Tests for font height functionality
├── _font_resource_test.v    # Tests for font resource loading
└── _text_height_test.v      # Tests for text height calculations
```

## Test Structure

**Suite Organization:**
Each test file is a flat list of test functions (no suite grouping).

```v
module vglyph

import gg

fn test_context_creation() {
    // Setup
    mut ctx := new_context(1.0) or {
        assert false, 'Failed to create context: ${err}'
        return
    }

    // Teardown
    defer { ctx.free() }

    // Test assertions
    // (implicit pass if no assertion fails)
}

fn test_layout_simple_text() {
    mut ctx := new_context(1.0)!
    defer { ctx.free() }

    cfg := TextConfig{
        style: TextStyle{
            font_name: 'Sans 20'
        }
        block: BlockStyle{
            width: -1
            align: .left
        }
    }

    layout := ctx.layout_text('Hello World', cfg)!

    assert layout.items.len > 0
    assert layout.char_rects.len == 'Hello World'.len
}
```

**Patterns:**

1. **Setup:**
   - Create minimal fixtures inline
   - Use config structs with defaults: `TextConfig{ style: TextStyle{ ... } }`
   - Initialize contexts with error handling:
     ```v
     mut ctx := new_context(1.0) or {
         assert false, 'Failed to create context: ${err}'
         return
     }
     ```
   - Or use `!` propagation syntax (newer tests): `mut ctx := new_context(1.0)!`

2. **Teardown:**
   - Use `defer` to clean up resources:
     ```v
     defer { ctx.free() }
     ```
   - Place immediately after initialization
   - Ensures cleanup even on early returns/assertions

3. **Assertion:**
   - Use `assert condition, 'message'` for main checks
   - Assert on observable outcomes: lengths, values, properties
   - Conditional assertions for optional features:
     ```v
     $if debug {
         assert layout.items[0].run_text == 'Hello World'
     }
     ```

## Mocking

**Framework:** No mocking framework; use nil pointers and unsafe blocks

**Patterns:**
```v
fn test_get_cache_key_consistency() {
    ts := TextSystem{
        ctx:      unsafe { nil }
        renderer: unsafe { nil }
        am:       unsafe { nil }
    }

    cfg1 := TextConfig{ ... }

    key1 := ts.get_cache_key('hello', cfg1)
    key2 := ts.get_cache_key('hello', cfg1)

    assert key1 != 0
    assert key1 == key2
}
```

**What to Mock:**
- Complex external systems (C libraries) that are not called in the test
- Expensive operations (file I/O) by passing nil or dummy values
- Graphics contexts that require window creation (pass nil in test, use real in examples)

**What NOT to Mock:**
- Core layout algorithm (always test real)
- Font loading (use actual system fonts or bundled test fonts)
- Cache behavior (test with real TextSystem)
- C FFI results (test against actual C libraries when possible)

## Fixtures and Factories

**Test Data:**
Built inline per test. Common config structs:

```v
// Repeated config pattern
cfg := TextConfig{
    style: TextStyle{
        font_name: 'Sans 20'
    }
    block: BlockStyle{
        width: -1
        align: .left
    }
}

// Font size variants
cfg_pixels := TextConfig{
    style: TextStyle{
        font_name: 'Sans 20px'
    }
}

// Rich text pattern
rt := RichText{
    runs: [
        StyleRun{ text: 'Hello', style: TextStyle{ ... } },
        StyleRun{ text: 'World', style: TextStyle{ ... } }
    ]
}
```

**Location:**
- Fixtures created inline in test functions
- No separate fixture files
- Test data created fresh for each test (no shared state)

## Coverage

**Requirements:** No coverage requirements enforced

**View Coverage:**
Not configured in this project

## Test Types

**Unit Tests:**
- Scope: Individual functions and small components
- Approach: Test with mocked dependencies (nil contexts for cache tests)
- Examples: `test_get_cache_key_consistency()`, `test_font_height_sanity()`
- Files: `_api_test.v`, `_font_height_test.v`, `_font_resource_test.v`

**Integration Tests:**
- Scope: Real layout pipeline with actual Pango/FreeType
- Approach: Create real Context, test full layout generation and queries
- Examples: `test_layout_simple_text()`, `test_layout_wrapping()`, `test_hit_test()`
- Files: `_layout_test.v`, `_text_height_test.v`

**System Tests:**
- Scope: End-to-end graphics rendering with sokol/gg
- Approach: Visual validation in examples
- Files: `examples/demo.v`, `examples/api_demo.v`, etc.
- Note: Not automated; run manually for visual inspection

## Common Patterns

**Async Testing:**
Not applicable (V is single-threaded in this codebase)

**Error Testing:**

1. **Expected Errors:**
```v
fn test_add_font_file() {
    mut ctx := new_context(1.0) or {
        assert false, 'failed to create context'
        return
    }
    defer { ctx.free() }

    // Test loading a non-existent file
    assert !ctx.add_font_file('/path/to/non_existent_file.ttf')

    // Test loading an existing file
    font_path := '${@DIR}/assets/feathericon.ttf'
    if true {
        assert ctx.add_font_file(font_path)
    }
}
```

2. **Error Propagation:**
```v
fn test_context_creation() {
    mut ctx := new_context(1.0) or {
        assert false, 'Failed to create context: ${err}'
        return
    }
    defer { ctx.free() }
}
```

3. **Optional Results:**
```v
fn test_hit_test_rect() {
    layout := ctx.layout_text('A', cfg)!

    rect := layout.hit_test_rect(5, 5) or {
        assert false, 'Should have hit'
        return
    }

    assert rect.width > 0
    assert rect.height > 0

    if _ := layout.hit_test_rect(-10, -10) {
        assert false, 'Should have missed'
    }
}
```

## Test Naming Convention

**Function Names:**
- `test_<what_is_being_tested>()`: `test_context_creation()`, `test_layout_simple_text()`
- Describe the behavior, not the implementation
- Use descriptive qualifiers: `test_cache_key_consistency()`, `test_cache_key_diff()`

**Comment Headers:**
Each test file may have brief comments above test functions:

```v
// Test context creation and cleanup
fn test_context_creation() { ... }

// Test basic layout generation
fn test_layout_simple_text() { ... }

// Test empty text
fn test_layout_empty_text() { ... }

// Test wrapping
fn test_layout_wrapping() { ... }

// Test hit testing
fn test_hit_test() { ... }
```

## Test Execution Flow

1. Test function is executed by V test runner
2. Setup phase: Create fixtures, initialize context with `defer` for cleanup
3. Assertion phase: Validate behavior with `assert` statements
4. Teardown phase: `defer` blocks execute (free resources)
5. Result: Pass if all assertions hold, fail if any assertion fails

## Context Management

**Real Context Tests:**
```v
fn test_layout_simple_text() {
    mut ctx := new_context(1.0)!           // Create real context
    defer { ctx.free() }                    // Guarantee cleanup

    layout := ctx.layout_text(text, cfg)!  // Use real layout
    assert layout.items.len > 0            // Validate result
}
```

**Mocked Context Tests:**
```v
fn test_get_cache_key_consistency() {
    ts := TextSystem{
        ctx:      unsafe { nil }            // Mock C context
        renderer: unsafe { nil }            // Not needed for this test
        am:       unsafe { nil }
    }

    // Test only hash consistency, not actual rendering
    key1 := ts.get_cache_key('hello', cfg1)
    assert key1 == key2
}
```

## Debug Output

**Printing in Tests:**
Use `println()` for debug output during test development:

```v
fn test_text_height_no_draw() {
    layout := ctx.layout_text('Hello', cfg)!

    println('Logical WxH: ${layout.width}x${layout.height}')
    println('Visual  WxH: ${layout.visual_width}x${layout.visual_height}')

    assert layout.visual_height >= 10.0
}
```

**Note:** `println()` output appears when running tests with `-v` flag

## Test Structure Recommendations for New Tests

When adding new tests, follow this template:

```v
module vglyph

import gg as _  // Import test dependencies

// Brief comment describing what is tested
fn test_feature_name() {
    // Setup: Create real context if testing layout algorithm
    mut ctx := new_context(1.0)!
    defer { ctx.free() }

    // Fixture: Create config and test data
    cfg := TextConfig{
        style: TextStyle{ ... }
        block: BlockStyle{ ... }
    }

    // Action: Call the function being tested
    result := ctx.layout_text(text, cfg)!

    // Assert: Validate expected behavior
    assert result.items.len > 0
    assert result.char_rects.len == text.len

    // Teardown happens automatically via defer
}
```

---

*Testing analysis: 2026-02-01*
