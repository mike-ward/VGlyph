# Phase 28: Profiling Validation - Context

**Gathered:** 2026-02-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Measure optimization impact from shelf packing (P26) and async uploads
(P27), validate improvements via stress testing, and make data-driven
go/no-go decision on shape caching (P29). No new optimizations — this
phase instruments, measures, and decides.

</domain>

<decisions>
## Implementation Decisions

### Profile output format
- New metrics inline with existing `-d profile` output, same style
- Atlas utilization: aggregate percentage only (no per-page breakdown)
- Upload time: absolute time in ms (no frame budget percentage)
- LayoutCache hit rate: percentage only (no hit/miss counts)

### Measurement methodology
- New standalone stress test example binary in `examples/`
- Full multilingual content: ASCII + Latin extended + CJK + emoji
- Exercises maximum atlas diversity and cache path coverage
- Before/after comparison approach: Claude's discretion

### Decision threshold for P29
- Threshold value: Claude's discretion based on profiling results
- Auto-decide: Phase 28 verification writes recommendation to
  ROADMAP.md, user reviews
- If P29 skipped: v1.6 complete at Phase 28, P29 removed or marked N/A
- Profiling report includes full analysis paragraph explaining numbers
  and rationale for skip/proceed

### Regression detection
- Anomaly flagging vs raw metrics: Claude's discretion
- Variance tracking (avg vs avg+worst-case): Claude's discretion
- Stress test is one-time for v1.6, not a permanent benchmark
- Profiling report with P29 recommendation lives in VERIFICATION.md

### Claude's Discretion
- Threshold value for P29 decision (roadmap suggests 70%)
- Whether to log metrics to file for comparison or terminal-only
- Regression flagging approach (warn on anomalies vs raw numbers)
- Frame variance tracking (averages only vs avg+worst-case)
- Before/after comparison mechanism
- Stress test content specifics (exact text, glyph counts)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 28-profiling-validation*
*Context gathered: 2026-02-05*
