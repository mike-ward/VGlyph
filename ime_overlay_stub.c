// IME Overlay Stub for Non-Darwin Platforms
// No-op implementations for platforms that don't use NSTextInputClient

#ifndef __APPLE__

#include <stddef.h>
#include "ime_overlay_darwin.h"

// Create overlay (no-op on non-Darwin)
void* vglyph_create_ime_overlay(void* mtk_view) {
    return NULL;
}

// Focus management (no-op on non-Darwin)
void vglyph_set_focused_field(void* handle, const char* field_id) {
    // No-op
}

// Free overlay (no-op on non-Darwin)
void vglyph_overlay_free(void* handle) {
    // No-op
}

// Register callbacks (no-op on non-Darwin)
void vglyph_overlay_register_callbacks(void* handle, VGlyphIMECallbacks callbacks) {
    (void)handle;
    (void)callbacks;
    // No-op
}

// Discover MTKView (no-op on non-Darwin)
void* vglyph_discover_mtkview_from_window(void* ns_window) {
    (void)ns_window;
    return NULL;
}

// Create overlay via auto-discovery (no-op on non-Darwin)
void* vglyph_create_ime_overlay_auto(void* ns_window) {
    (void)ns_window;
    return NULL;
}

#endif // !__APPLE__
