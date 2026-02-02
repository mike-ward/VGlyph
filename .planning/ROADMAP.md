# Roadmap: VGlyph

## Milestones

- ✅ **v1.0 Memory Safety** — Phases 1-3 (shipped 2026-02-02)
- ✅ **v1.1 Fragile Area Hardening** — Phases 4-7 (shipped 2026-02-02)
- 🚧 **v1.2 Performance Optimization** — Phases 8-10 (active)

## Phases

<details>
<summary>✅ v1.0 Memory Safety (Phases 1-3) — SHIPPED 2026-02-02</summary>

- [x] Phase 1: Error Propagation (1/1 plans) — completed 2026-02-01
- [x] Phase 2: Memory Safety (1/1 plans) — completed 2026-02-01
- [x] Phase 3: Layout Safety (1/1 plans) — completed 2026-02-02

</details>

<details>
<summary>✅ v1.1 Fragile Area Hardening (Phases 4-7) — SHIPPED 2026-02-02</summary>

- [x] Phase 4: Layout Iteration (1/1 plans) — completed 2026-02-02
- [x] Phase 5: Attribute List (1/1 plans) — completed 2026-02-02
- [x] Phase 6: FreeType State (1/1 plans) — completed 2026-02-02
- [x] Phase 7: Vertical Coords (1/1 plans) — completed 2026-02-02

</details>

### 🚧 v1.2 Performance Optimization (Phases 8-10)

#### Phase 8: Instrumentation

**Goal:** Profiling builds expose performance characteristics with zero release overhead

**Dependencies:** None

**Plans:** 2 plans

Plans:
- [ ] 08-01-PLAN.md — ProfileMetrics struct + timing instrumentation (INST-01, INST-02)
- [ ] 08-02-PLAN.md — Cache/atlas tracking + API exposure (INST-03, INST-04, INST-05)

**Requirements:**
- INST-01: Profiling builds with `-d profile` flag have zero release overhead
- INST-02: Frame time breakdown shows layout/rasterize/upload/draw phases
- INST-03: Cache hit/miss rates tracked for glyph, metrics, and layout caches
- INST-04: Memory allocation tracking shows peak usage and growth rate
- INST-05: Atlas utilization metrics show used/total pixels per page

**Success Criteria:**
1. Developer builds with `-d profile` and sees frame time breakdown in milliseconds
2. Cache hit rates show percentages for each cache type (glyph, metrics, layout)
3. Memory tracking shows peak atlas usage and growth rate per frame
4. Atlas metrics show utilization percentage per page
5. Release builds have zero profiling overhead (conditional compilation verified)

#### Phase 9: Latency Optimizations

**Goal:** Hot paths execute with minimal stalls and redundant computation

**Dependencies:** Phase 8 (instrumentation validates improvements)

**Requirements:**
- LATENCY-01: Multi-page atlas eliminates mid-frame reset stalls
- LATENCY-02: FreeType metrics cached by (font, size) tuple
- LATENCY-03: Glyph cache validates hash collisions with secondary key
- LATENCY-04: Color emoji scaling uses GPU or cached scaled bitmaps

**Success Criteria:**
1. Rendering large text never triggers mid-frame atlas reset (multi-page support)
2. Metrics cache reduces FreeType FFI calls (cache hit rate >80% in typical usage)
3. Glyph cache handles hash collisions without corrupting atlas (secondary key validation)
4. Color emoji rendering uses GPU scaling or cached bitmaps (no per-frame CPU bicubic)

#### Phase 10: Memory Optimization

**Goal:** Cache memory usage bounded and predictable

**Dependencies:** Phase 8 (instrumentation shows memory growth)

**Requirements:**
- MEM-01: Glyph cache uses LRU eviction with configurable max entries

**Success Criteria:**
1. Glyph cache respects max entry limit (configurable, default reasonable)
2. LRU eviction removes least-recently-used glyphs when limit reached
3. Memory tracking shows cache stabilizes after warmup (no unbounded growth)

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Error Propagation | v1.0 | 1/1 | Complete | 2026-02-01 |
| 2. Memory Safety | v1.0 | 1/1 | Complete | 2026-02-01 |
| 3. Layout Safety | v1.0 | 1/1 | Complete | 2026-02-02 |
| 4. Layout Iteration | v1.1 | 1/1 | Complete | 2026-02-02 |
| 5. Attribute List | v1.1 | 1/1 | Complete | 2026-02-02 |
| 6. FreeType State | v1.1 | 1/1 | Complete | 2026-02-02 |
| 7. Vertical Coords | v1.1 | 1/1 | Complete | 2026-02-02 |
| 8. Instrumentation | v1.2 | 0/2 | Planned | — |
| 9. Latency Optimizations | v1.2 | 0/? | Pending | — |
| 10. Memory Optimization | v1.2 | 0/? | Pending | — |
