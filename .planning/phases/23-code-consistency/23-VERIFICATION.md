---
phase: 23-code-consistency
verified: 2026-02-04T22:10:15Z
status: gaps_found
score: 8/9 requirements verified
gaps:
  - truth: "All tests pass after error message convention changes"
    status: failed
    reason: "Tests expect capitalized error messages but Plan 23-02 lowercased them"
    artifacts:
      - path: "_validation_test.v"
        issue: "Tests check for 'Invalid UTF-8', 'Empty string', 'Path traversal', 'Empty font path' (capitalized)"
      - path: "_api_test.v"
        issue: "Tests check for 'Invalid UTF-8', 'Empty string', 'Path traversal' (capitalized)"
    missing:
      - "Update test assertions to use lowercase: 'invalid UTF-8', 'empty string', 'path traversal', 'empty font path'"
---

# Phase 23: Code Consistency Verification Report

**Phase Goal:** Codebase follows uniform conventions for naming, structure, and formatting
**Verified:** 2026-02-04T22:10:15Z
**Status:** gaps_found
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | All source files pass v fmt -verify | VERIFIED | `v fmt -verify *.v accessibility/*.v` exits 0 |
| 2 | No source lines exceed 99 chars | VERIFIED | `awk 'length > 99' *.v accessibility/*.v` returns empty |
| 3 | All test files follow _*_test.v pattern | VERIFIED | 6 test files all named `_*_test.v` |
| 4 | Functions use snake_case | VERIFIED | `rg '^(pub )?fn [A-Z]' *.v` shows only C bindings (excluded) |
| 5 | Types use PascalCase | VERIFIED | `rg '^(pub )?struct [A-Z]' *.v` matches all structs |
| 6 | Error handling uses V idioms | VERIFIED | All panics documented with $if debug or comments |
| 7 | Struct fields grouped logically | VERIFIED | pub:/pub mut:/mut: separation consistent |
| 8 | All pub fn have doc comments | VERIFIED | awk check shows 0 missing |
| 9 | Tests pass after convention changes | FAILED | 2 test files fail due to case mismatch |

**Score:** 8/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `*.v` | Formatted source | VERIFIED | v fmt -verify passes |
| `accessibility/*.v` | Formatted source | VERIFIED | v fmt -verify passes |
| `_*_test.v` | Test files | VERIFIED | 6 files match pattern |
| `validation.v` | Lowercase errors | VERIFIED | Error messages lowercase |
| `_validation_test.v` | Updated assertions | FAILED | Still expects capitalized |
| `_api_test.v` | Updated assertions | FAILED | Still expects capitalized |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| validation.v | error() | lowercase msgs | WIRED | All errors lowercase |
| _validation_test.v | contains() | assertions | BROKEN | Expects capitalized |
| _api_test.v | contains() | assertions | BROKEN | Expects capitalized |

### Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| CON-01 Functions snake_case | SATISFIED | - |
| CON-02 Variables snake_case | SATISFIED | Enforced by V compiler |
| CON-03 Types PascalCase | SATISFIED | - |
| CON-04 Module partitioning logical | SATISFIED | - |
| CON-05 Test files _*_test.v | SATISFIED | - |
| CON-06 Error handling V idioms | SATISFIED | - |
| CON-07 Struct fields grouped | SATISFIED | - |
| CON-08 v fmt compliance | SATISFIED | - |
| CON-09 Lines <= 99 chars | SATISFIED | - |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| _validation_test.v | 27,36,68,86 | Case mismatch | Blocker | Tests fail |
| _api_test.v | 125,141,171,225 | Case mismatch | Blocker | Tests fail |

### Human Verification Required

None - all checks are programmatic.

### Gaps Summary

Plan 23-02 correctly lowercased error messages in `validation.v` per V convention (CON-06),
but the corresponding test files were not updated. The tests in `_validation_test.v` and
`_api_test.v` still assert against capitalized error strings like 'Invalid UTF-8' when
the actual errors now say 'invalid UTF-8 encoding'.

**Fix required:** Update 8 test assertions to match lowercase error messages:
- `_validation_test.v:27` - 'Invalid UTF-8' -> 'invalid UTF-8'
- `_validation_test.v:36` - 'Empty string' -> 'empty string'
- `_validation_test.v:68` - 'Path traversal' -> 'path traversal'
- `_validation_test.v:86` - 'Empty font path' -> 'empty font path'
- `_api_test.v:125` - 'Invalid UTF-8' -> 'invalid UTF-8'
- `_api_test.v:141` - 'Empty string' -> 'empty string'
- `_api_test.v:171` - 'Path traversal' -> 'path traversal'
- `_api_test.v:225` - 'Invalid UTF-8' -> 'invalid UTF-8'

---

*Verified: 2026-02-04T22:10:15Z*
*Verifier: Claude (gsd-verifier)*
