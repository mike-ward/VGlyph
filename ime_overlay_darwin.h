// IME Overlay for macOS
// Transparent NSView overlay that receives IME events above MTKView
// Phase 18: Infrastructure only (protocol stubs)
// Phase 19: Full NSTextInputClient implementation

#ifndef VGLYPH_IME_OVERLAY_DARWIN_H
#define VGLYPH_IME_OVERLAY_DARWIN_H

#include <stdbool.h>

// Opaque handle to overlay view
typedef void* VGlyphOverlayHandle;

// Callback structure for IME events
typedef struct {
    void (*on_marked_text)(const char* text, int cursor_pos, void* user_data);
    void (*on_insert_text)(const char* text, void* user_data);
    void (*on_unmark_text)(void* user_data);
    // Get bounds for composition text (for candidate window positioning)
    // Returns true if bounds valid, fills x/y/width/height in VIEW coordinates
    bool (*on_get_bounds)(void* user_data, float* x, float* y, float* width, float* height);
    // Clause segmentation callbacks (for rendering preedit with style)
    // style: 0=raw, 1=converted, 2=selected (thick underline)
    void (*on_clause)(int start, int length, int style, void* user_data);
    void (*on_clauses_begin)(void* user_data);  // Called before clause enumeration
    void (*on_clauses_end)(void* user_data);    // Called after all clauses reported
    void* user_data;
} VGlyphIMECallbacks;

// Discover MTKView from NSWindow via view hierarchy walk
// Returns MTKView pointer or NULL if not found (logs to stderr)
void* vglyph_discover_mtkview_from_window(void* ns_window);

// Create overlay via auto-discovery from NSWindow
// Walks NSWindow view hierarchy to find MTKView, then creates overlay
// Returns handle or NULL on failure (MTKView not found, or creation error)
VGlyphOverlayHandle vglyph_create_ime_overlay_auto(void* ns_window);

// Create overlay as sibling above MTKView
// mtk_view: Pointer to sokol's MTKView (casted from sapp_macos_get_window())
// Returns: Handle to overlay, or NULL on failure
VGlyphOverlayHandle vglyph_create_ime_overlay(void* mtk_view);

// Focus management - switches first responder
// handle: Overlay handle from vglyph_create_ime_overlay
// field_id: Field identifier (NULL = blur, non-NULL = focus)
void vglyph_set_focused_field(VGlyphOverlayHandle handle, const char* field_id);

// Free overlay and remove from view hierarchy
// handle: Overlay handle from vglyph_create_ime_overlay
void vglyph_overlay_free(VGlyphOverlayHandle handle);

// Register callbacks for IME events
// handle: Overlay handle from vglyph_create_ime_overlay
// callbacks: Structure containing callback function pointers
void vglyph_overlay_register_callbacks(VGlyphOverlayHandle handle, VGlyphIMECallbacks callbacks);

#endif // VGLYPH_IME_OVERLAY_DARWIN_H
