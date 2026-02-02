# Requirements: VGlyph

**Defined:** 2026-02-02
**Core Value:** Reliable text rendering without crashes or undefined behavior

## v1.1 Requirements

Requirements for Fragile Area Hardening milestone.

### Layout Iteration

- [ ] **ITER-01**: Iterator wrapper with automatic cleanup via defer
- [ ] **ITER-02**: Documentation of iterator lifecycle rules in code
- [ ] **ITER-03**: Guard against iterator reuse after exhaustion

### Attribute List

- [ ] **ATTR-01**: Ownership documentation (who unrefs what)
- [ ] **ATTR-02**: Safe API that prevents double-free
- [ ] **ATTR-03**: Leak validation in debug builds

### FreeType State

- [ ] **FT-01**: Document mandatory load→translate→render sequence
- [ ] **FT-02**: State validation before translate in debug builds
- [ ] **FT-03**: Consistent fallback path handling (matches normal path)

### Vertical Coords

- [ ] **VERT-01**: Inline documentation of coordinate transform logic
- [ ] **VERT-02**: Exhaustive orientation enum matching
- [ ] **VERT-03**: Clearer upright vs rotated distinction

## Future Requirements

Deferred to later milestones.

### Performance

- **PERF-01**: Multi-page atlas with LRU eviction
- **PERF-02**: Glyph cache collision detection
- **PERF-03**: FreeType metrics caching
- **PERF-04**: GPU-based bitmap scaling

### Test Coverage

- **TEST-01**: Error path tests (OOM, load failures)
- **TEST-02**: Edge case tests (empty layout, RTL+vertical)
- **TEST-03**: Memory stress tests

## Out of Scope

Explicitly excluded from v1.1.

| Feature | Reason |
|---------|--------|
| Performance optimizations | Separate concern, defer to v1.2+ |
| Test coverage expansion | Separate concern, defer to v1.2+ |
| Thread safety | V is single-threaded by design |
| API breaking changes | Hardening should preserve existing API |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ITER-01 | TBD | Pending |
| ITER-02 | TBD | Pending |
| ITER-03 | TBD | Pending |
| ATTR-01 | TBD | Pending |
| ATTR-02 | TBD | Pending |
| ATTR-03 | TBD | Pending |
| FT-01 | TBD | Pending |
| FT-02 | TBD | Pending |
| FT-03 | TBD | Pending |
| VERT-01 | TBD | Pending |
| VERT-02 | TBD | Pending |
| VERT-03 | TBD | Pending |

**Coverage:**
- v1.1 requirements: 12 total
- Mapped to phases: 0
- Unmapped: 12 ⚠️

---
*Requirements defined: 2026-02-02*
*Last updated: 2026-02-02 after initial definition*
