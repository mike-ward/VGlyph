---
phase: 37-layout-cache-optimization
plan: 01
subsystem: telemetry
tags: [telemetry, profiling, cache]
requires: []
provides: [layout-cache-metrics]
affects: [37-02-PLAN.md]
tech-stack:
  added: []
  patterns: [telemetry-enrichment]
key-files:
  created: []
  modified: [context.v, api.v, examples/stress_demo.v]
decisions:
  - Metric names: Used layout_cache_size and layout_cache_evictions for consistency with glyph cache metrics.
metrics:
  duration: 10m
  completed: 2026-02-06
---

# Phase 37 Plan 01: Layout Cache Metrics Summary

## Substantive Deliverables
- **Extended ProfileMetrics**: Added `layout_cache_size` and `layout_cache_evictions` to the profiling struct.
- **Enhanced print_summary**: Updated the summary output to include layout cache utilization and eviction data.
- **TextSystem Telemetry**: Added `eviction_count` tracking to `TextSystem` and exposed it via `get_profile_metrics`.
- **Stress Demo Update**: `examples/stress_demo.v` now automatically prints profiling data every 600 frames when run with `-d profile`.

## Task Commits
- 25a904c: feat(37-01): extend ProfileMetrics with layout cache size and evictions
- e1d767c: feat(37-01): update TextSystem telemetry for layout cache
- 6c475ed: feat(37-01): update stress_demo to print profile summary

## Deviations from Plan
None - plan executed exactly as written.

## Self-Check: PASSED
- [x] ProfileMetrics contains layout_cache_size and layout_cache_evictions.
- [x] TextSystem correctly tracks evictions.
- [x] print_summary output includes "Layout Cache: ... X evictions, size Y".
- [x] stress_demo.v outputs profiling data when run with -d profile.
