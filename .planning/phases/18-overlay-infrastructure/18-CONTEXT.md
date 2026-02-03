# Phase 18: Overlay Infrastructure - Context

**Gathered:** 2026-02-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Create NSView overlay that can become first responder to receive CJK IME events. The overlay
is transparent infrastructure — it exists to forward NSTextInputClient protocol messages to
VGlyph's CompositionState. Actual IME protocol implementation is Phase 19.

</domain>

<decisions>
## Implementation Decisions

### View hierarchy
- Host app adds overlay to view hierarchy (VGlyph provides class, doesn't inject)
- Overlay is opt-in — apps without it still get dead keys, just no CJK IME
- No warning if CJK IME detected without overlay (silent graceful degradation)
- Overlay uses Auto Layout constraints to match MTKView bounds

### API surface
- Factory function: `vglyph_create_ime_overlay(mtkView)` returns configured overlay
- Focus notification: `vglyph_set_focused_field(field_id)` — host calls on focus change
- Blur via null: `vglyph_set_focused_field(NULL)` resigns first responder
- Direct internal calls: overlay calls CompositionState methods directly (not callbacks)

### Platform abstraction
- Separate file: `ime_overlay_darwin.m` guarded by `#if __APPLE__`
- Stub file: `ime_overlay_stub.c` provides no-op implementations for non-Darwin
- Factory returns null on non-Darwin, all calls are silent no-ops
- API designed for portability — same surface can be implemented on Windows/Linux later

### Claude's Discretion
- NSTextInputClient protocol stub method implementations
- Exact Auto Layout constraint setup
- First responder claiming/resigning mechanics
- Hit testing configuration (clicks pass through to MTKView)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 18-overlay-infrastructure*
*Context gathered: 2026-02-03*
