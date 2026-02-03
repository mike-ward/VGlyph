// IME Bridge forward declarations
// This header makes the Obj-C functions visible to V's generated C code.

#ifndef VGLYPH_IME_BRIDGE_MACOS_H
#define VGLYPH_IME_BRIDGE_MACOS_H

#include <stdbool.h>

// Callback types matching c_bindings.v
typedef void (*IMEMarkedTextCallback)(const char* text, int cursor_pos, void* user_data);
typedef void (*IMEInsertTextCallback)(const char* text, void* user_data);
typedef void (*IMEUnmarkTextCallback)(void* user_data);
typedef bool (*IMEBoundsCallback)(void* user_data, float* x, float* y, float* width, float* height);

// Register callbacks from V code
void vglyph_ime_register_callbacks(IMEMarkedTextCallback marked,
                                   IMEInsertTextCallback insert,
                                   IMEUnmarkTextCallback unmark,
                                   IMEBoundsCallback bounds,
                                   void* user_data);

#endif // VGLYPH_IME_BRIDGE_MACOS_H
