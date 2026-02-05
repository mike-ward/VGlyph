# Phase 27: Async Texture Updates - Context

**Gathered:** 2026-02-05
**Status:** Ready for planning

<domain>
## Phase Boundary

GPU uploads overlapped with CPU rasterization via double-buffered staging.
Atlas pages get front/back staging buffers so CPU can rasterize into one
while GPU reads from the other. No API changes — this is internal pipeline
optimization. commit() → draw ordering must be preserved.

</domain>

<decisions>
## Implementation Decisions

### Staging buffer strategy
- 2 buffers per atlas page (not a shared pool)
- Allocate both buffers upfront when atlas page is created
- No lazy allocation — predictable memory footprint

### Failure/fallback behavior
- Kill switch: add a flag/option to force synchronous uploads
  (disable async entirely for debugging or compatibility)

### Claude's Discretion
- Buffer swap timing (commit-time vs draw-time) — pick based on
  existing commit/draw pipeline structure
- Dirty tracking granularity (per-page vs per-region) — pick based
  on typical atlas update patterns
- Allocation failure handling — pick safest fallback approach
- Error/fallback visibility — follow existing error reporting patterns
- Backpressure when CPU outpaces GPU — follow Metal best practices

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Success criteria
from roadmap define the measurable targets:
- Double-buffered pixel staging per atlas page
- CPU rasterization overlaps with GPU upload
- commit() → draw ordering preserved
- Upload time visible in -d profile metrics

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 27-async-texture-updates*
*Context gathered: 2026-02-05*
