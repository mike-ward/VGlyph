# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-03)

**Core value:** Reliable text rendering without crashes or undefined behavior
**Current focus:** v1.4 CJK IME — Phase 20 Korean + Keyboard Integration

## Current Position

Phase: 20 of 21 (Korean + Keyboard Integration)
Plan: 20-01 at Task 4 checkpoint (human verify), 20-02 COMPLETE
Status: Debugging Korean first-keypress issue
Last activity: 2026-02-04 — Fixed backspace (DEL char 127), Korean timing issue remains

Progress: ██████████████████████████████ 33.5/34+ plans

## Performance Metrics

Latest profiled build metrics (from v1.2 Phase 10):
- Glyph cache: 4096 entries (LRU eviction)
- Metrics cache: 256 entries (LRU eviction)
- Atlas: Multi-page (4 max), LRU page eviction
- Layout cache: TTL-based eviction
- Frame timing: instrumented via `-d profile`

## Accumulated Context

### Decisions

See PROJECT.md Key Decisions table for full history.

v1.3 key decisions archived:
- Byte-to-logattr mapping for UTF-8/emoji cursor
- Anchor-focus selection model
- Pure function mutation (MutationResult)
- 1s coalescing timeout for undo
- 150ms announcement debounce

v1.4 approach decision:
- Overlay NSView architecture (transparent sibling above MTKView)
- No sokol modifications (project constraint)

v1.4 Phase 18 decisions:
- Overlay sibling positioning: Sibling above MTKView (not child) to avoid Metal rendering
- ARC memory management: __bridge_retained for C ownership transfer

v1.4 Phase 19 decisions:
- Per-overlay callbacks (not global) to support multiple text fields
- cursor_pos in callback is selectedRange.location (byte offset within preedit)
- Thick underline = selected clause (style=2), other underlines = raw (style=0)
- Y-flip: self.bounds.size.height - y - h for macOS bottom-left origin
- Handler methods on CompositionState to encapsulate callback processing
- TextSystem.draw_composition wraps Renderer (private) for public API

v1.4 Phase 20 decisions:
- Block undo/redo entirely during composition (prevents state corruption)
- Option+Backspace cancels composition (discards preedit, not commit)
- Cmd+A commits then selects (less surprising than blocking)

### Pending Todos

None.

### Blockers/Concerns

**Overlay API limitation** (documented 2026-02-04):
- editor_demo uses global callback API because gg doesn't expose MTKView handle
- Overlay API is implemented but registration commented out pending native handle access
- Single-field apps work fine; multi-field apps need native handle access

### Known Issues

**Korean IME first-keypress issue** (active):
- Korean composition works on SECOND keypress, not first
- Root cause: ime_bridge_macos.m swizzles sokol's _sapp_macos_view keyDown
- Swizzling timing: tried +load dispatch_async, lazy in inputContext, on callback registration
- None work because sokol's view class may not exist or first event already processed
- Need to investigate when _sapp_macos_view is created vs when callbacks registered

**Attempted fixes in ime_bridge_macos.m:**
1. dispatch_async in +load → too late
2. Lazy ensureSwizzling() in inputContext → too late (called during first keypress)
3. ensureSwizzling() in vglyph_ime_register_callbacks() → still too late

**Key insight:** The callbacks are registered in gg's init_fn. Need to verify sokol's view exists then.

## Session Continuity

Last session: 2026-02-04
Stopped at: Debugging Korean first-keypress (swizzling timing)
Resume file: None
Resume command: `/gsd:execute-phase 20` (will resume from 20-01 checkpoint)

**Debug approach to try next:**
- Add printf in ensureSwizzling() to verify it runs and finds _sapp_macos_view
- Check if callbacks are registered BEFORE or AFTER sokol creates its view
- May need to swizzle NSView.keyDown instead of _sapp_macos_view.keyDown
