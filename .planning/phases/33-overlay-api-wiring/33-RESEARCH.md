# Phase 33: Overlay API Wiring - Research

**Researched:** 2026-02-05
**Domain:** Objective-C view hierarchy traversal, C/V API design
**Confidence:** HIGH

## Summary

Phase 33 wires per-overlay IME callbacks through MTKView discovery so
editor_demo uses overlay API instead of global callbacks. Research
shows:

1. **NSWindow → MTKView discovery** - Simple recursive view walk,
   sokol exposes NSWindow via sapp_macos_get_window()
2. **Discovery timing** - Must happen at overlay creation (not lazy) per
   CONTEXT.md
3. **Two-path API** - Auto-discover (NSWindow → MTKView) + explicit
   MTKView pointer for advanced use
4. **Global coexistence** - Both callback systems live at runtime, no
   migration needed

**Primary recommendation:** Obj-C helper with recursive subview walk
(depth-first), hard error on MTKView not found, two-entry-point API
(auto + explicit).

## Standard Stack

Established tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AppKit | macOS 10.6+ | View hierarchy traversal | Native system |
| Objective-C Runtime | macOS 10.0+ | NSClassFromString lookup | Dynamic class checks |
| sokol_app.h | Current | NSWindow exposure | Already used by gg |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| objc/runtime.h | macOS 10.0+ | Method swizzling (if needed) | Avoid - not needed here |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Recursive walk | Hardcoded NSWindow.contentView | Fragile - assumes sokol internals |
| NSClassFromString | isKindOfClass:[MTKView class] | Requires linking Metal framework |
| Auto-discover | Force explicit MTKView | Less ergonomic for simple apps |

**Installation:**
No new dependencies - AppKit + sokol already present

## Architecture Patterns

### Recommended Project Structure
```
vglyph/
├── ime_overlay_darwin.m     # Overlay implementation (exists)
├── ime_overlay_darwin.h     # Public API (exists)
├── ime_overlay_stub.c       # Linux/Windows stubs (exists)
└── ime_view_discovery.m     # NEW: MTKView discovery helper
```

### Pattern 1: Recursive View Hierarchy Walk
**What:** Depth-first traversal to find MTKView in NSWindow subviews
**When to use:** Auto-discovery from NSWindow
**Example:**
```objc
// Source: Verified AppKit pattern (HIGH confidence)
NSView* findMTKView(NSView* root) {
    if ([root.className isEqualToString:@"MTKView"]) {
        return root;
    }
    for (NSView* subview in root.subviews) {
        NSView* found = findMTKView(subview);
        if (found) return found;
    }
    return nil;
}

// Entry point from NSWindow
NSView* vglyph_discover_mtkview(void* ns_window) {
    NSWindow* window = (__bridge NSWindow*)ns_window;
    return findMTKView(window.contentView);
}
```

### Pattern 2: Two-Path API Design
**What:** Single API with optional NSWindow param for auto-discovery
**When to use:** Balance ergonomics and control
**Example:**
```objc
// Source: Standard C API pattern
// Auto-discover: pass NSWindow, gets MTKView via walk
VGlyphOverlayHandle vglyph_create_ime_overlay(void* mtk_view_or_window);

// Explicit: pass MTKView directly (advanced)
VGlyphOverlayHandle vglyph_create_ime_overlay_from_view(void* mtk_view);
```

**Recommendation:** Use two separate functions (clearer intent) vs
auto-detect heuristic

### Pattern 3: Hard Error on Not Found
**What:** Return NULL immediately if MTKView missing, log to stderr
**When to use:** Per CONTEXT.md decision - caller handles explicitly
**Example:**
```objc
if (!mtk_view) {
    fprintf(stderr, "vglyph: MTKView not found in window hierarchy\n");
    return NULL;
}
```

### Anti-Patterns to Avoid
- **Lazy discovery:** CONTEXT.md specifies creation-time discovery, not
  lazy. Avoids race conditions with window setup.
- **Silent fallback:** Don't fall back to global callbacks automatically
  — return error so caller decides.
- **Deep recursion without limit:** View hierarchies rarely exceed 10
  levels, but add sanity check (depth > 100).

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Class name matching | String compare "MTKView" | NSClassFromString + pointer check | Robust to class renaming |
| View hierarchy cycle detection | Manual visited set | Depth limit (sokol hierarchy simple) | AppKit guarantees DAG |
| NSWindow → contentView path | Hardcode assumptions | Direct property access | Sokol may change internals |

**Key insight:** View traversal is well-understood pattern, don't
optimize prematurely

## Common Pitfalls

### Pitfall 1: Assuming MTKView is contentView Child
**What goes wrong:** Code assumes `window.contentView.subviews[0]` is
MTKView
**Why it happens:** Sokol may wrap MTKView in container for layout
**How to avoid:** Recursive walk entire tree, don't hardcode depth
**Warning signs:** Discovery fails when sokol changes window structure

### Pitfall 2: Using isKindOfClass Without Import
**What goes wrong:** `[view isKindOfClass:[MTKView class]]` crashes if
Metal not linked
**Why it happens:** MTKView class symbol missing at runtime
**How to avoid:** Use `className` string comparison instead
**Warning signs:** Linker errors or runtime crashes on class lookup

### Pitfall 3: Forgetting NULL Check Before Bridge Cast
**What goes wrong:** `(__bridge NSWindow*)NULL` used in walk causes
crash
**Why it happens:** Caller passes NULL sokol window
**How to avoid:** Guard at entry: `if (!ns_window) return NULL;`
**Warning signs:** Crash in Obj-C code during discovery

### Pitfall 4: Leaking Obj-C Objects in C API
**What goes wrong:** Return bare NSView* without ownership transfer
**Why it happens:** ARC confusion in C/Obj-C boundary
**How to avoid:** Use `__bridge` (no transfer) for input, already done
correctly in existing `vglyph_create_ime_overlay`
**Warning signs:** Memory leaks in long-running apps

### Pitfall 5: Cross-Platform Stub Returns Non-NULL
**What goes wrong:** Linux stub returns non-NULL, V code thinks overlay
works
**Why it happens:** Copy-paste error in stub
**How to avoid:** Verify `ime_overlay_stub.c` always returns NULL for
all functions
**Warning signs:** Tests pass on macOS, fail on Linux with wrong IME path

## Code Examples

Verified patterns from official sources:

### View Hierarchy Walk (Obj-C)
```objc
// Source: Standard AppKit pattern (HIGH confidence)
static NSView* findViewByClass(NSView* root, NSString* className, int depth) {
    // Sanity check - prevent infinite recursion
    if (depth > 100) {
        return nil;
    }

    if ([root.className isEqualToString:className]) {
        return root;
    }

    for (NSView* subview in root.subviews) {
        NSView* found = findViewByClass(subview, className, depth + 1);
        if (found) {
            return found;
        }
    }

    return nil;
}

// Public API
NSView* vglyph_discover_mtkview_from_window(void* ns_window) {
    if (!ns_window) {
        return NULL;
    }

    NSWindow* window = (__bridge NSWindow*)ns_window;
    NSView* contentView = window.contentView;
    if (!contentView) {
        return NULL;
    }

    NSView* mtkView = findViewByClass(contentView, @"MTKView", 0);
    if (!mtkView) {
        fprintf(stderr, "vglyph: MTKView not found in window view hierarchy\n");
    }
    return mtkView;
}
```

### Two-Path Creation (C Header)
```c
// Source: Existing ime_overlay_darwin.h + recommended extension
// Auto-discover MTKView from NSWindow
VGlyphOverlayHandle vglyph_create_ime_overlay_auto(void* ns_window);

// Explicit MTKView (existing function, rename for clarity)
VGlyphOverlayHandle vglyph_create_ime_overlay(void* mtk_view);
```

### V Bindings
```v
// Source: Existing c_bindings.v pattern
fn C.vglyph_create_ime_overlay_auto(ns_window voidptr) voidptr
fn C.vglyph_create_ime_overlay(mtk_view voidptr) voidptr

pub fn ime_overlay_create_auto(ns_window voidptr) voidptr {
    return C.vglyph_create_ime_overlay_auto(ns_window)
}

pub fn ime_overlay_create(mtk_view voidptr) voidptr {
    return C.vglyph_create_ime_overlay(mtk_view)
}
```

### Demo Integration (V)
```v
// Source: editor_demo.v current pattern + overlay wiring
fn init(state_ptr voidptr) {
    mut state := unsafe { &EditorState(state_ptr) }
    state.ts = vglyph.new_text_system(mut state.gg_ctx) or { panic(err) }

    // Get NSWindow from sokol (gg wraps sokol)
    ns_window := sapp.macos_get_window()

    // Create overlay via auto-discovery
    state.ime_overlay = vglyph.ime_overlay_create_auto(ns_window)
    if state.ime_overlay == unsafe { nil } {
        eprintln('Warning: IME overlay creation failed, falling back to global callbacks')
        // Fallback to global API
        vglyph.ime_register_callbacks(ime_marked_text, ime_insert_text,
            ime_unmark_text, ime_bounds, state_ptr)
    } else {
        // Register per-overlay callbacks
        vglyph.ime_overlay_register_callbacks(state.ime_overlay,
            ime_on_marked_text, ime_on_insert_text, ime_on_unmark_text,
            ime_on_get_bounds, ime_on_clause, ime_on_clauses_begin,
            ime_on_clauses_end, state_ptr)
    }

    // Rest of init...
}
```

### Status Text Rendering (V)
```v
// Source: editor_demo.v frame() function pattern
fn frame(state_ptr voidptr) {
    mut state := unsafe { &EditorState(state_ptr) }
    state.gg_ctx.begin()

    // ... existing rendering ...

    // Status bar - show IME path
    status_y := f32(window_height - 25)

    // IME path indicator (right side)
    ime_path := if state.ime_overlay != unsafe { nil } {
        'IME: overlay'
    } else {
        'IME: global'
    }
    state.gg_ctx.draw_text(window_width - 120, int(status_y), ime_path,
        color: gg.gray)

    // ... rest of status bar ...
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Global IME callbacks only | Per-overlay + global coexist | v1.8 (Phase 33) | Multi-field apps supported |
| Manual MTKView pointer passing | Auto-discovery from NSWindow | v1.8 (Phase 33) | Simpler API for common case |
| No discovery helper | Obj-C view walk helper | v1.8 (Phase 33) | Decouples from sokol internals |

**Deprecated/outdated:**
- Hardcoded NSWindow.contentView child access - sokol may change
  structure
- Global-only IME callbacks - kept for compatibility but overlay
  preferred

## Open Questions

Things that couldn't be fully resolved:

1. **Walk depth limit**
   - What we know: Sokol window hierarchy is simple (typically 2-3 levels)
   - What's unclear: Exact max depth before sanity abort
   - Recommendation: 100 depth limit (far exceeds expected, catches cycles)

2. **Discovery function file location**
   - What we know: Need Obj-C helper for view walk
   - What's unclear: Separate `ime_view_discovery.m` or add to
     `ime_overlay_darwin.m`
   - Recommendation: Add to `ime_overlay_darwin.m` - single compilation
     unit simpler

3. **Status text placement**
   - What we know: Show "overlay" vs "global" in demo
   - What's unclear: Exact position in status bar
   - Recommendation: Right side after undo depth (consistent with info
     displays)

4. **--global-ime flag parsing**
   - What we know: Command-line flag to force global callbacks
   - What's unclear: V flag parsing lib or manual os.args check
   - Recommendation: Manual `os.args.contains('--global-ime')` - no new
     deps

5. **Multi-field demo scope**
   - What we know: Two fields proves multi-field capability
   - What's unclear: Include in Phase 33 or defer?
   - Recommendation: Defer to future - Phase 33 proves single field works,
     overlay API already supports multi via field_id

## Sources

### Primary (HIGH confidence)
- AppKit NSView documentation - `subviews` property, view hierarchy
- Existing vglyph codebase - `ime_overlay_darwin.m`, `c_bindings.v`,
  `editor_demo.v`
- CONTEXT.md (Phase 33) - User decisions on discovery timing, error
  handling
- sokol_app.h - `sapp_macos_get_window()` exposure (verified in
  accessibility code)

### Secondary (MEDIUM confidence)
- Phase 18 RESEARCH.md - Overlay architecture patterns
- Phase 15 RESEARCH.md - NSTextInputClient integration patterns

### Tertiary (LOW confidence)
- None - all findings verified against codebase or official docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - AppKit/sokol already used, no new libs
- Architecture: HIGH - Patterns verified in existing overlay code
- Pitfalls: MEDIUM - Extrapolated from common Obj-C/C boundary issues

**Research date:** 2026-02-05
**Valid until:** ~90 days (AppKit APIs stable, sokol stable)
