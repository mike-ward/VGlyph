# VGlyph v1.6 Performance Optimization Research Summary

**Project:** VGlyph v1.6 Performance Optimization
**Domain:** Text rendering performance
**Researched:** 2026-02-04
**Confidence:** MEDIUM-HIGH

## Executive Summary

Text renderer performance optimization follows well-established patterns: efficient atlas
packing (shelf algorithms), overlapped CPU/GPU work (async uploads), and shaping reuse (plan
caching). VGlyph already has strong foundation (multi-page atlas, LRU caches, profiling) —
v1.6 optimizes hot paths without architectural changes.

Recommended approach: pure V implementation for all features. Shelf packing uses
best-height-fit algorithm (proven in Firefox/Mapbox). Async uploads use double-buffered
staging (sokol abstraction prevents true PBOs). Shape plan caching may be redundant —
existing layout cache likely sufficient, validate with profiling first.

Critical risks: maintain existing cache invalidation patterns, avoid fragmentation from
partial page resets, preserve commit/upload ordering. V's single-threaded nature eliminates
concurrency pitfalls, focus on correctness over performance complexity.

## Key Findings

### Recommended Stack

Pure V implementation, zero dependencies. Shelf packing (~120 LOC), double-buffering (~50
LOC), cache tuning (~30 LOC). Existing stack unchanged: Pango/HarfBuzz/FreeType for
rendering, Sokol/gg for GPU.

**Core technologies:**
- **Shelf Best-Height-Fit** (pure V) — proven in Firefox etagere, Mapbox shelf-pack
- **Double-buffered staging** (pure V) — sokol abstraction prevents raw PBO access
- **Layout cache tuning** (existing) — may eliminate need for HarfBuzz direct caching

**What NOT to add:**
- External bin packing libs (JS/Rust, ~100 LOC in V sufficient)
- PBOs (sokol abstracts GL, staging achieves same benefit)
- Compute shaders (FreeType already fast, bandwidth is bottleneck)

### Expected Features

**Must have (v1.6):**
- Shelf packing with best-height-fit heuristic (10-15% atlas utilization improvement)
- Shelf merging on deallocation (prevent vertical fragmentation)
- Double-buffered pixel data per atlas page (20-30% upload time reduction)
- Atlas utilization tracking (integrate with existing `-d profile`)

**Should have (v1.6):**
- Layout cache TTL increase (100ms → 500ms, text changes infrequent)
- Layout cache size limit (LRU eviction when >256 entries)
- Shape cost profiling (track layout_time_ns hit rate)

**Defer (post-v1.6):**
- Two-column shelf split (complexity, marginal gain)
- Persistent buffer mapping (GL 4.4+, fence sync complexity)
- Direct HarfBuzz bindings (Pango caching likely sufficient)
- Upload batching (marginal over double-buffering)

### Architecture Approach

Replace row-based atlas allocation with shelf allocator. Add staging buffers to Renderer.
Tune existing LayoutCache before adding HarfBuzz layer.

**Modified components:**
1. **GlyphAtlas.insert_bitmap()** — shelf allocator replaces row logic
2. **AtlasPage struct** — add `shelves []Shelf` tracking
3. **Renderer.commit()** — swap staging buffers before upload
4. **AtlasPage pixel data** — double-buffer: buffer_a/buffer_b

**Integration points:**
- Shelf allocator wraps AtlasPage, maintains same error returns/CachedGlyph output
- Staging writes during insert_bitmap(), upload during commit() (preserves ordering)
- Layout cache tuning before HarfBuzz cache (may make it redundant)

**Data flow change:**
```
Current: insert_bitmap [row-based] → copy_to_page → commit [sync upload]
With shelf: insert_bitmap [shelf-alloc] → copy_to_staging → commit [swap+upload]
```

### Critical Pitfalls

1. **Vertical fragmentation from partial shelf reset** — reset entire page (not individual
   shelves) to avoid mid-page gaps. Existing code already does page-level reset, preserve
   this.

2. **Shelf height waste** — first glyph sets height. Use bins (0-32px, 32-64px, 64-256px)
   to reduce waste. Target: >75% utilization (industry standard).

3. **Glyph cache invalidation after reset** — existing code deletes cache entries for reset
   page (renderer.v:313-317). Shelf packing must preserve this loop.

4. **Upload-after-draw ordering** — commit() must upload before next frame draws. V
   single-threaded simplifies (no CPU races), but GPU commands async. Preserve existing
   commit() → draws ordering.

5. **Pango abstracts HarfBuzz** — direct shape plan caching complex. Existing LayoutCache
   already caches shaped results. Profile hit rate before adding HarfBuzz layer (likely
   redundant).

## Implications for Roadmap

Suggested 3-phase structure: shelf packing (high confidence, immediate wins) → async uploads
(medium confidence, measurable but sokol-limited) → shape cache evaluation (low confidence,
validate need first).

### Phase 1: Shelf Packing Allocator
**Rationale:** Low risk, high reward. Algorithm well-understood (Firefox/Mapbox proven). Pure
V, no dependencies. Immediate utilization improvement.

**Delivers:** Shelf packer module, integrated atlas allocation, utilization metrics.

**Addresses:**
- Shelf best-height-fit allocation (FEATURES.md table stakes)
- Shelf merging on deallocation (prevent fragmentation)
- Waste factor tracking (profiling visibility)

**Avoids:**
- Vertical fragmentation (reset entire page, not individual shelves)
- Height waste (use bins: small/med/large)
- Cache invalidation (preserve existing deletion loop)

**Success criteria:**
- Atlas utilization >75% (vs current ~60-70%)
- atlas_debug example shows shelf boundaries
- No cache collision panics in debug builds

### Phase 2: Async Texture Updates
**Rationale:** Measurable frame time reduction, but sokol abstraction limits true async.
Double-buffered staging achieves CPU/GPU overlap without raw PBOs. Complexity moderate,
benefit GPU-dependent.

**Delivers:** Double-buffered pixel data per page, staging buffer management, upload time
metrics.

**Addresses:**
- Double-buffered PBOs equivalent (FEATURES.md table stakes)
- Upload time profiling (differentiator)

**Avoids:**
- Upload-after-draw bug (preserve commit() → draws ordering)
- Over-engineering for V (single PBO, no threading)
- Atlas grow corruption (preserve cleanup() deferred destroy)

**Success criteria:**
- 5-10% frame time reduction on glyph-heavy frames
- upload_time_ns metric shows improvement
- No visual corruption (glyphs visible immediately)

### Phase 3: Shape Plan Cache Evaluation
**Rationale:** Existing LayoutCache may make this redundant. Pango abstracts HarfBuzz (no
direct control). Profile first to validate need before implementing.

**Delivers:** LayoutCache hit/miss instrumentation. If needed: HarfBuzz cache with LRU
eviction.

**Addresses (if profiling shows need):**
- hb_shape_plan_create_cached integration (FEATURES.md table stakes)
- Cache size limit with LRU (256 entries, match MetricsCache pattern)
- Cache hit tracking (profiling differentiator)

**Avoids:**
- Font change invalidation (include face ptr in key)
- Memory bloat (LRU with 256 entry limit)
- Size change miss (include physical pixel size in key)
- Feature hash collision (FNV-1a like existing LayoutCache)
- Lifetime bugs (reference() on cache, destroy() on evict)

**Success criteria:**
- LayoutCache hit rate instrumented (baseline established)
- If miss rate >20%, proceed with HarfBuzz cache
- If miss rate <20%, defer (existing cache sufficient)

### Phase Ordering Rationale

- **Shelf first:** Independent of other optimizations, immediate measurable improvement, low
  integration risk. Builds foundation (better utilization = fewer page resets = less cache
  churn).

- **Async second:** Depends on stable atlas allocation (shelf packing). Profiling shelf
  gains informs async priority (if atlas resets reduced, upload optimization less critical).

- **Shape cache last:** May be unnecessary (LayoutCache sufficient). Profiling phases 1-2
  provides data to decide. Pango abstraction makes this complex, defer until proven needed.

### Research Flags

**Needs deeper research during planning:**
- **Phase 2 (async uploads):** Sokol abstraction limits. May need raw GL investigation if
  double-buffering insufficient. Risk: breaks abstraction, Metal/D3D11 incompatibility.

**Standard patterns (skip research-phase):**
- **Phase 1 (shelf packing):** Well-documented algorithm, clear implementation path. Firefox
  etagere, Mapbox shelf-pack provide reference.
- **Phase 3 (shape cache):** If implemented, HarfBuzz API well-documented. Integration
  pattern matches existing MetricsCache.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Pure V, zero dependencies. Shelf algorithm proven. Staging pattern clear. |
| Features | MEDIUM | Table stakes clear, differentiators speculative (performance impact workload-dependent). |
| Architecture | MEDIUM | Integration points identified, but sokol async limits unclear until tested. |
| Pitfalls | HIGH | VGlyph-specific risks identified from codebase review. Existing patterns well-understood. |

**Overall confidence:** MEDIUM-HIGH

Shelf packing: HIGH (proven algorithm, clear integration). Async uploads: MEDIUM (sokol
limits, need profiling). Shape cache: LOW (may be redundant, validate first).

### Gaps to Address

- **Current atlas allocator details:** Research assumes row-based, verify actual
  implementation before shelf integration.

- **OpenGL version target:** Affects PBO features available. If GL 4.4+, persistent mapping
  possible (deferred differentiator). If GL 3.3, limited to double-buffering.

- **Typical glyph size distribution:** Affects shelf bin choices. Profiling existing atlas
  informs bin boundaries (currently assumed: 0-32px, 32-64px, 64-256px).

- **Font switching frequency:** Affects shape plan cache value. High frequency = cache churn
  (low benefit). Low frequency = cache hits (high benefit). Workload-dependent.

- **LayoutCache hit rate baseline:** Phase 3 decision depends on this. Instrument before
  implementing HarfBuzz cache.

## Sources

### Primary (HIGH confidence)
- [Mapbox shelf-pack](https://github.com/mapbox/shelf-pack) — reference implementation,
  1,610 ops/sec benchmark
- [Firefox etagere](https://nical.github.io/posts/etagere.html) — production rationale,
  shelf > guillotine for simplicity
- [HarfBuzz shape plan docs](https://harfbuzz.github.io/shaping-plans-and-caching.html) —
  official caching API
- [OpenGL PBO tutorial](https://www.songho.ca/opengl/gl_pbo.html) — async upload pattern
- [Sokol sg_update_image](https://github.com/floooh/sokol/issues/567) — partial update
  discussion

### Secondary (MEDIUM confidence)
- [Roomanna shelf algorithms](https://blog.roomanna.com/09-25-2015/binpacking-shelf) —
  first-fit vs best-area comparison
- [lisyarus texture packing](https://lisyarus.github.io/blog/posts/texture-packing.html) —
  algorithm tradeoffs
- [Stray Pixels font packing](https://straypixels.net/texture-packing-for-fonts/) — glyph
  specific considerations
- [Mozilla Bugzilla 1679751](https://bugzilla.mozilla.org/show_bug.cgi?id=1679751) — shelf
  allocator fragmentation discussion

### VGlyph Codebase (HIGH confidence)
- glyph_atlas.v — multi-page LRU eviction, grow() deferred cleanup, row-based allocation
- renderer.v — glyph cache invalidation loop, commit() upload ordering
- api.v — LayoutCache FNV-1a hashing pattern
- PROJECT.md — cache sizes (glyph: 4096, metrics: 256, layout: 10K entries)

---
*Research completed: 2026-02-04*
*Ready for roadmap: yes*
