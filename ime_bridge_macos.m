// IME Bridge for macOS
// Implements NSTextInputClient protocol on sokol's NSView to receive IME events
// and forward them to VGlyph composition state via callbacks.
//
// BUILD INTEGRATION:
// To link this Objective-C file into V applications:
// 1. Add to V source: #flag darwin ime_bridge_macos.m
// 2. Or compile manually: clang -c -fobjc-arc ime_bridge_macos.m -o ime_bridge_macos.o
// 3. Link during V build: v -cflags "-framework Cocoa" your_app.v ime_bridge_macos.o
//
// The native bridge is initialized by calling vglyph_ime_register_callbacks() from V.

#import <Cocoa/Cocoa.h>

// Forward declarations for V callback types
typedef void (*IMEMarkedTextCallback)(const char* text, int cursor_pos, void* user_data);
typedef void (*IMEInsertTextCallback)(const char* text, void* user_data);
typedef void (*IMEUnmarkTextCallback)(void* user_data);
typedef bool (*IMEBoundsCallback)(void* user_data, float* x, float* y, float* width, float* height);

// Global callback state
static IMEMarkedTextCallback g_marked_callback = NULL;
static IMEInsertTextCallback g_insert_callback = NULL;
static IMEUnmarkTextCallback g_unmark_callback = NULL;
static IMEBoundsCallback g_bounds_callback = NULL;
static void* g_user_data = NULL;

// Register callbacks from V code
void vglyph_ime_register_callbacks(IMEMarkedTextCallback marked,
                                   IMEInsertTextCallback insert,
                                   IMEUnmarkTextCallback unmark,
                                   IMEBoundsCallback bounds,
                                   void* user_data) {
    g_marked_callback = marked;
    g_insert_callback = insert;
    g_unmark_callback = unmark;
    g_bounds_callback = bounds;
    g_user_data = user_data;
}

// Category to add NSTextInputClient protocol to sokol's NSView
// Sokol creates its view dynamically, so we add IME support via category.
@interface NSView (VGlyphIME)
@end

@implementation NSView (VGlyphIME)

#pragma mark - NSTextInputClient Required Methods

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    NSString* text = [string isKindOfClass:[NSAttributedString class]]
                     ? [(NSAttributedString*)string string]
                     : (NSString*)string;

    if (g_insert_callback) {
        g_insert_callback([text UTF8String], g_user_data);
    }
}

- (void)setMarkedText:(id)string
       selectedRange:(NSRange)selectedRange
    replacementRange:(NSRange)replacementRange {
    NSString* text = [string isKindOfClass:[NSAttributedString class]]
                     ? [(NSAttributedString*)string string]
                     : (NSString*)string;

    // selectedRange.location is cursor position within preedit
    int cursor_pos = (int)selectedRange.location;

    if (g_marked_callback) {
        g_marked_callback([text UTF8String], cursor_pos, g_user_data);
    }
}

- (void)unmarkText {
    if (g_unmark_callback) {
        g_unmark_callback(g_user_data);
    }
}

- (NSRange)selectedRange {
    // Not tracking selection ranges in V yet - return empty
    return NSMakeRange(NSNotFound, 0);
}

- (NSRange)markedRange {
    // Would need to query composition state from V
    // For now return no marked range when not composing
    return NSMakeRange(NSNotFound, 0);
}

- (BOOL)hasMarkedText {
    // Would need to query composition state from V
    return NO;
}

- (nullable NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range
                                                         actualRange:(nullable NSRangePointer)actualRange {
    // Would need to extract substring from document
    return nil;
}

- (NSArray<NSAttributedStringKey> *)validAttributesForMarkedText {
    return @[];
}

- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(nullable NSRangePointer)actualRange {
    // Query V for composition bounds
    if (g_bounds_callback) {
        float x = 0, y = 0, width = 0, height = 0;
        if (g_bounds_callback(g_user_data, &x, &y, &width, &height)) {
            // Convert from top-left origin to bottom-left (macOS screen coordinates)
            NSScreen* screen = [[NSScreen screens] firstObject];
            float screen_height = screen.frame.size.height;

            // Get window position
            NSWindow* window = [self window];
            NSRect windowFrame = [window frame];

            // Convert view coordinates to screen coordinates
            // y needs to be flipped: screen_height - (windowFrame.origin.y + windowFrame.size.height - y - height)
            float screen_x = windowFrame.origin.x + x;
            float screen_y = screen_height - (windowFrame.origin.y + windowFrame.size.height - y);

            return NSMakeRect(screen_x, screen_y, width, height);
        }
    }

    // Fallback: return caret position at window center
    NSRect windowFrame = [[self window] frame];
    return NSMakeRect(windowFrame.origin.x + 100, windowFrame.origin.y + 100, 1, 20);
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point {
    return NSNotFound;
}

@end
