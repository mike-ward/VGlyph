---
phase: 33-overlay-api-wiring
plan: 02
subsystem: editor-demo
tags: [ime, overlay, multi-field, nswindow, nstextinputclient]

# Dependency graph
requires:
  - phase: 33-overlay-api-wiring
    plan: 01
    provides: "MTKView auto-discovery and auto-create C API"
provides:
  - "editor_demo uses per-overlay IME with two independent text fields"
  - "Global fallback via --global-ime flag"
  - "Status bar IME path indicator"
  - "Force-cancel on overlay destroy"
affects: [IME-01, IME-02, IME-03, IME-04, IME-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Lazy overlay init in frame() (window not ready in init)"
    - "dispatch_async for makeFirstResponder during render"
    - "_didInsertText flag prevents triple character echo"
    - "VGlyphIMEOverlayView overrides inputContext (category conflict)"

key-files:
  created: []
  modified:
    - examples/editor_demo.v
    - ime_overlay_darwin.m

key-decisions:
  - "Lazy init in frame() — sokol init callback runs before window"
  - "Override inputContext on overlay — NSView category returns nil"
  - "Standard interpretKeyEvents only — handleEvent breaks Korean"
  - "Always reclaim overlay focus on click — hitTest:nil steals it"
  - "Global callbacks route to active_field for --global-ime mode"

patterns-established:
  - "Per-overlay callback pattern with field-specific state routing"
  - "Lazy window-dependent init with ime_initialized guard"

# Metrics
duration: ~45min (including 6 checkpoint iterations)
completed: 2026-02-05
---

# Phase 33 Plan 02: Editor Demo Overlay Wiring Summary

**editor_demo wired to per-overlay IME API with two fields, global
fallback, and status indicator**

## Performance

- **Tasks:** 1 (+ 6 fix iterations during checkpoint)
- **Files modified:** 2

## Accomplishments

- editor_demo creates overlays via `ime_overlay_create_auto` on first
  frame (lazy init — window not ready during sokol init)
- Two independent text fields with separate overlays and callbacks
- `--global-ime` flag falls back to v1.7 global callback path
- Global callbacks route IME events to active field
- Status bar shows "IME: overlay" or "IME: global"
- Force-cancel composition on overlay destroy
- Japanese, Chinese, Korean IME all work through overlay path

## Key Fixes During Checkpoint

1. **isKindOfClass for MTKView** — sokol's `_sapp_macos_view` extends
   MTKView; exact string match fails
2. **Lazy frame() init** — `sapp_macos_get_window()` returns NULL
   during V/gg init callback
3. **Own inputContext** — NSView category in ime_bridge_macos.m
   overrides inputContext for ALL NSViews, returning nil when global
   callbacks unregistered
4. **dispatch_async makeFirstResponder** — doesn't stick during Metal
   render callback
5. **_didInsertText flag** — prevents triple character echo (handleEvent
   + interpretKeyEvents + sokol .char event)
6. **Standard interpretKeyEvents only** — handleEvent consumes Korean
   IME events without calling NSTextInputClient methods

## Task Commits

1. **Wire editor_demo to per-overlay API** — `6eb4be2` (feat)
2. **Defer IME overlay init, route global callbacks** — `1043bc7` (fix)
3. **isKindOfClass for MTKView discovery** — `a469879` (fix)
4. **Move overlay back to init, reclaim focus on click** — `89554d6`
5. **Own inputContext, defer makeFirstResponder** — `8cd74a0` (fix)
6. **Prevent triple character echo** — `d362b2f` (fix)
7. **Standard interpretKeyEvents for Korean** — `06063ca` (fix)

## Deviations from Plan

- Overlay creation moved from init() to frame() lazy init (window
  timing discovery)
- VGlyphIMEOverlayView needed inputContext override (category conflict)
- keyDown simplified to interpretKeyEvents only (handleEvent broke
  Korean IME)
- Multiple fix iterations required for correct event flow

## Issues Encountered

- Korean first-keypress macOS bug persists (known upstream:
  QTBUG-136128, Apple FB17460926, Alacritty #6942)

---
*Phase: 33-overlay-api-wiring*
*Completed: 2026-02-05*
