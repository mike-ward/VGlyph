# Requirements: VGlyph

**Defined:** 2026-02-02
**Core Value:** Reliable text rendering without crashes or undefined behavior

## v1.2 Requirements

Requirements for performance optimization milestone.

### Instrumentation

- [ ] **INST-01**: Profiling builds with `-d profile` flag have zero release overhead
- [ ] **INST-02**: Frame time breakdown shows layout/rasterize/upload/draw phases
- [ ] **INST-03**: Cache hit/miss rates tracked for glyph, metrics, and layout caches
- [ ] **INST-04**: Memory allocation tracking shows peak usage and growth rate
- [ ] **INST-05**: Atlas utilization metrics show used/total pixels per page

### Latency

- [ ] **LATENCY-01**: Multi-page atlas eliminates mid-frame reset stalls
- [ ] **LATENCY-02**: FreeType metrics cached by (font, size) tuple
- [ ] **LATENCY-03**: Glyph cache validates hash collisions with secondary key
- [ ] **LATENCY-04**: Color emoji scaling uses GPU or cached scaled bitmaps

### Memory

- [ ] **MEM-01**: Glyph cache uses LRU eviction with configurable max entries

## Future Requirements

Deferred to post-v1.2.

### Atlas Optimization

- **ATLAS-01**: Shelf packing allocator for better atlas utilization
- **ATLAS-02**: Async texture updates to eliminate glTexSubImage stalls
- **ATLAS-03**: Workload separation (glyphs vs images)

### Additional Caching

- **CACHE-01**: Shape plan caching for HarfBuzz overhead reduction

## Out of Scope

| Feature | Reason |
|---------|--------|
| Vector texture rendering | Harder on GPU than bitmap atlas, VGlyph uses FreeType |
| Thread pool rasterization | V is single-threaded by design |
| SDF (Signed Distance Fields) | Quality feature, not performance; GPU cost higher |
| Pre-rendered atlases | App size bloat, character set unknown at build |
| Custom memory allocator | Premature; VGlyph has overflow validation |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INST-01 | Phase 8 | Pending |
| INST-02 | Phase 8 | Pending |
| INST-03 | Phase 8 | Pending |
| INST-04 | Phase 8 | Pending |
| INST-05 | Phase 8 | Pending |
| LATENCY-01 | Phase 9 | Pending |
| LATENCY-02 | Phase 9 | Pending |
| LATENCY-03 | Phase 9 | Pending |
| LATENCY-04 | Phase 9 | Pending |
| MEM-01 | Phase 10 | Pending |

**Coverage:**
- v1.2 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-02-02*
*Last updated: 2026-02-02 after initial definition*
