# Phase 25: Verification - Research

**Researched:** 2026-02-04
**Domain:** Test execution, smoke testing, verification documentation
**Confidence:** HIGH

## Summary

Phase 25 verifies all tests pass and examples run after audit phases 22-24. User decided local test execution only (`v test .`), automated example runs (script-based), and immediate failure-stop with fix-immediately approach. Pre-existing known issues (Korean IME first-keypress, overlay API) don't block.

Standard approach: automated test runner + example compiler checks + structured verification report. V language test framework is simple (`v test .` runs all `_test.v` files), examples can be syntax-checked without execution using `v -check-syntax`. Smoke testing best practices emphasize fast feedback (under 15 minutes), isolation, and stable environments.

**Primary recommendation:** Shell script that runs `v test .` (fail-fast), compiles all examples with `v -check` (verify buildability without GUI launch), generates VERIFICATION.md summary report.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| V test framework | built-in | Unit test execution | Native V testing, zero dependencies |
| Bash/Shell | system | Test automation scripting | Universal, simple, CI-compatible |
| timeout command | GNU coreutils | Prevent hanging tests | Standard Unix tool for time limits |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| v -check-syntax | built-in | Syntax-only validation | Fast compile check without execution |
| v -check | built-in | Full compile check | Verify buildability including dependencies |
| exit codes | POSIX | Success/failure signaling | Standard shell scripting mechanism |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shell script | V program | V more complex for simple orchestration, shell universal |
| Headless rendering | Skip GUI tests | Sokol lacks headless mode, compilation confirms correctness |
| Manual runs | Automated script | Manual error-prone, doesn't scale, not repeatable |

**Installation:**
```bash
# No installation needed - all tools are built-in V or system utilities
```

## Architecture Patterns

### Recommended Script Structure
```
.planning/phases/25-verification/
├── verify.sh               # Main verification script
└── 25-VERIFICATION.md      # Generated report (output)
```

### Pattern 1: Fail-Fast Test Execution
**What:** Stop immediately on first test failure, fix before continuing
**When to use:** Verification gate phases where all tests must pass

**Example:**
```bash
# Run tests with immediate failure
v test . || {
    echo "VERIFICATION BLOCKED: Tests failing"
    echo "Fix all test failures before continuing phase 25"
    exit 1
}
```

### Pattern 2: Compile-Only Example Verification
**What:** Check examples compile without launching GUI windows
**When to use:** Sokol GUI apps where headless rendering unavailable

**Example:**
```bash
# Verify example builds without running
for example in examples/*.v; do
    v -check "$example" 2>&1 || {
        echo "FAILED: $example does not compile"
        exit 1
    }
done
```

### Pattern 3: Structured Report Generation
**What:** Generate summary report with pass/fail counts, not full output
**When to use:** Phase completion verification artifacts

**Example:**
```bash
# Generate VERIFICATION.md
cat > VERIFICATION.md <<EOF
# Phase 25: Verification Report

**Status:** passed
**Tests:** $test_count passed
**Examples:** $example_count compiled successfully
**Issues:** None
EOF
```

### Anti-Patterns to Avoid
- **Silent failures:** Always capture and report failure details before exit
- **Verbose output:** Full test logs clutter reports; summary sufficient
- **Parallel example compilation:** Can mask individual failures; run sequential
- **Ignoring exit codes:** Must check `$?` or use `set -e` for fail-fast

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test execution | Custom test runner | `v test .` | V's built-in runner handles parallel execution, timing, stats |
| Timeout handling | Sleep loops + kill | `timeout` command | POSIX-standard, handles signals correctly (exit 124 on timeout) |
| Exit code checking | Manual `$?` checks everywhere | `set -e` flag | Shell fails immediately on any error in pipeline |
| Report formatting | String concatenation | Heredoc `cat <<EOF` | Cleaner, preserves formatting, no escaping needed |

**Key insight:** V's test framework and shell built-ins handle 90% of verification needs. Custom tooling adds complexity without benefit.

## Common Pitfalls

### Pitfall 1: Flaky Tests from Timing
**What goes wrong:** Tests pass sometimes, fail others due to timing/environment
**Why it happens:** Asynchronous behavior, network dependencies, shared state
**How to avoid:** Isolate test data, use consistent environments, eliminate external dependencies
**Warning signs:** Intermittent failures, "works on my machine", CI vs local differences

### Pitfall 2: False Positives from Incomplete Checks
**What goes wrong:** Tests pass but functionality broken
**Why it happens:** Insufficient assertions, only checking happy path
**How to avoid:** Verify error cases too, check all relevant aspects of behavior
**Warning signs:** Bugs in production despite passing tests, obvious edge cases uncovered

### Pitfall 3: GUI Tests That Require Visual Verification
**What goes wrong:** Attempting to programmatically verify visual correctness
**Why it happens:** No headless rendering support, pixel-perfect verification fragile
**How to avoid:** Compile-only checks for examples, manual smoke tests documented separately
**Warning signs:** Complex pixel comparison logic, screenshot diffing infrastructure

### Pitfall 4: Ignoring Known Issues Incorrectly
**What goes wrong:** Blocking on pre-existing bugs that aren't phase-related
**Why it happens:** Unclear which issues are acceptable vs blockers
**How to avoid:** Document known issues explicitly (Korean IME first-keypress, overlay API), verify they're unchanged
**Warning signs:** Phase blocked on unrelated bugs, scope creep into old issues

### Pitfall 5: Overwhelming Report Output
**What goes wrong:** Verification report includes 10,000 lines of test output
**Why it happens:** Dumping raw logs instead of summary
**How to avoid:** Report summary (X passed, Y failed, list of failures), not full logs
**Warning signs:** Reports too long to review, failure details buried in noise

## Code Examples

Verified patterns from V documentation and testing best practices:

### V Test Execution
```bash
# Source: V documentation testing.html
# Run all tests in current directory
v test .

# Output format:
# OK [1/6] C: 4345.8 ms, R: 426.923 ms /path/to/_test.v
# Summary: 6 passed, 6 total. Elapsed: 9036 ms
```

### Example Compilation Check
```bash
# Source: V compiler built-in flags
# Check syntax without running (fast, no dependencies)
v -check-syntax examples/demo.v

# Full compilation check (includes dependency resolution)
v -check examples/demo.v

# Both exit with code 0 on success, non-zero on failure
```

### Fail-Fast Script Pattern
```bash
#!/bin/bash
# Source: Shell scripting best practices + timeout man page
set -e  # Exit immediately on any error

echo "Running tests..."
timeout 300 v test . || {
    echo "Tests failed or timed out (5 min limit)"
    exit 1
}

echo "Compiling examples..."
for example in examples/*.v; do
    timeout 60 v -check "$example" || {
        echo "Failed: $example"
        exit 1
    }
done

echo "All checks passed"
```

### Verification Report Template
```bash
# Source: NASA V&V Plan Outline + DVP&R standards
cat > VERIFICATION.md <<'EOF'
# Phase 25: Verification Report

**Verified:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Status:** passed

## Test Execution
- Total tests: 6
- Passed: 6
- Failed: 0

## Example Compilation
- Total examples: 22
- Compiled successfully: 22
- Failed: 0

## Known Issues (Non-Blocking)
- Korean IME first-keypress: Pre-existing, documented in Phase 20
- Overlay API: Pre-existing limitation

## Summary
All automated verification passed. Phase 25 complete.
EOF
```

### Known Issue Verification
```bash
# Verify known issues haven't changed (no new failures)
# Source: Phase 20 and 24 verification reports

# Known issues from context:
# - Korean IME first-keypress after focus (Phase 20)
# - No overlay API limitations

# If tests pass that previously documented known issues,
# that's an improvement, not a failure
# If new test failures appear, block immediately
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual test runs | `v test .` automated | V 0.1+ | Parallel execution, consistent results |
| Run examples manually | `v -check` compile-only | V compiler flags | No GUI launch needed, faster feedback |
| Verbose test output | Summary reports | 2026 QA trends | Faster review, less noise |
| Retry flaky tests | Fix root cause immediately | 2026 testing practices | Eliminates false positives |
| Reactive bug fixing | Shift-left verification | 2026 DevOps | Catch issues earlier |

**Deprecated/outdated:**
- Running tests without timeout: Modern practice uses timeout (5-15 min max) to prevent hanging
- Ignoring flaky tests: 2026 best practice is quarantine and fix, not skip

## Open Questions

Things that couldn't be fully resolved:

1. **Manual smoke test automation**
   - What we know: User requires manual smoke tests (text rendering, editing, IME)
   - What's unclear: Whether these should be documented in VERIFICATION.md or separate
   - Recommendation: Document in VERIFICATION.md under "Manual Verification Required" section

2. **Example success criteria**
   - What we know: User defined success as "starts without error (exit code 0 or window opens)"
   - What's unclear: How to verify "window opens" without running (compile-only doesn't launch)
   - Recommendation: Use `v -check` (compilation) as proxy for "can start"; actual launch is manual

3. **Timeout values**
   - What we know: Tests currently take ~9 seconds total
   - What's unclear: Appropriate timeout for catching hangs vs allowing slow CI
   - Recommendation: 5 minutes (300s) for full test suite, 60s per example compile

## Sources

### Primary (HIGH confidence)
- [V Documentation - Testing](https://docs.vlang.io/testing.html) - V test framework features
- [timeout man page](https://man7.org/linux/man-pages/man1/timeout.1.html) - Exit codes and usage
- [Baeldung - Bash Timeouts](https://www.baeldung.com/linux/bash-timeouts) - Shell timeout patterns
- Verified against actual codebase: 6 test files, 22 example programs, current test output

### Secondary (MEDIUM confidence)
- [BrowserStack - Smoke Testing Guide](https://www.browserstack.com/guide/smoke-testing-automation) - Best practices
- [ScienceDirect - Verification Reports](https://www.sciencedirect.com/topics/computer-science/verification-report) - Report structure
- [FHWA - Verification Documents Template](https://ops.fhwa.dot.gov/seits/sections/section6/6_8.html) - Government standards
- [ACCELQ - Flaky Tests 2026](https://www.accelq.com/blog/flaky-tests/) - Modern testing pitfalls

### Tertiary (LOW confidence)
- General GUI testing tools (Selenium, Puppeteer): Not applicable to V/Sokol native apps
- Sokol headless rendering: No evidence found in 2026 documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - V built-in tools, verified working in codebase
- Architecture: HIGH - Shell patterns verified against V documentation and actual tests
- Pitfalls: HIGH - Cross-referenced with 2026 testing literature and Phase 20/24 verification reports

**Research date:** 2026-02-04
**Valid until:** 2026-03-04 (30 days - V language stable, testing practices mature)
