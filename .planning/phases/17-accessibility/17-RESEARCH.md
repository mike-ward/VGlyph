# Phase 17: Accessibility - Research

**Researched:** 2026-02-03
**Domain:** VoiceOver screen reader support for text editing
**Confidence:** MEDIUM

## Summary

VoiceOver support enables blind/low-vision users to navigate and edit text with full auditory feedback.
On macOS, accessibility integration uses the NSAccessibility protocol to expose UI structure and state
to assistive technologies. For text editing, this requires implementing text-specific attributes
(selectedText, selectedTextRange, numberOfCharacters), notification posting when state changes (value
changed, selection changed), and optionally announcement APIs for explicit feedback.

VGlyph already has basic accessibility infrastructure: AccessibilityManager, backend_darwin.v with
NSAccessibilityElement bindings, and tree update mechanisms. Phase 17 extends this for text editing:
(1) add text field role with required attributes, (2) post notifications on cursor/selection/text
changes, (3) implement announcements for navigation/editing feedback per user decisions in CONTEXT.md.

Key decision from research: macOS NSAccessibility lacks a direct "announcement" notification like iOS's
UIAccessibilityAnnouncementNotification. VoiceOver primarily works via property changes + notifications.
Custom announcements require alternative approaches (e.g., updating a hidden element's value).

**Primary recommendation:** Extend AccessibilityManager with text field role, post standard
notifications for state changes, implement announcement helper for explicit feedback per user verbosity
decisions.

## Standard Stack

### Core macOS APIs (Already in VGlyph)
| API | Version | Purpose | Why Standard |
|-----|---------|---------|--------------|
| NSAccessibility protocol | macOS 10.10+ | Accessibility integration | Required for VoiceOver |
| NSAccessibilityElement | macOS 10.10+ | Custom element creation | Used in backend_darwin.v |
| NSAccessibilityPostNotification | macOS 10.10+ | State change notifications | VoiceOver tracking |

### Text-Specific Attributes (Need to Add)
| Attribute | Purpose | When Required |
|-----------|---------|---------------|
| `NSAccessibilityValueAttribute` | Text content | All text fields |
| `NSAccessibilitySelectedTextAttribute` | Selected text | When selection exists |
| `NSAccessibilitySelectedTextRangeAttribute` | Selection range | Always (range/location) |
| `NSAccessibilityNumberOfCharactersAttribute` | Text length | All text fields |
| `NSAccessibilityInsertionPointLineNumberAttribute` | Cursor line | Multi-line fields |

### Notification Types (Need to Implement)
| Notification | When to Post | Effect |
|--------------|--------------|--------|
| `NSAccessibilityValueChangedNotification` | Text mutated | VoiceOver reads change |
| `NSAccessibilitySelectedTextChangedNotification` | Selection changed | VoiceOver announces |
| `NSAccessibilitySelectedChildrenChangedNotification` | Focus moved | VoiceOver tracks focus |

### VGlyph APIs to Leverage (Existing)
| API | Location | Purpose | Status |
|-----|----------|---------|--------|
| `Layout.get_cursor_pos` | layout_query.v | Cursor position | Working |
| `Layout.get_char_rect` | layout_query.v | Character bounds | Working |
| `Layout.get_selection_rects` | layout_query.v | Selection ranges | Working |
| `MutationResult` | layout_mutation.v | Change tracking | Working |
| `AccessibilityManager` | accessibility/manager.v | Tree management | Working |

**Installation:** No additional libraries - uses macOS system frameworks (AppKit/Cocoa).

## Architecture Patterns

### Recommended Component Structure
```
Accessibility Integration for Text Editing:

1. TextFieldAccessibilityNode (Extends AccessibilityNode)
   - role: .text_field (new role)
   - value: string                    # Current text content
   - selected_range: Range            # Selection start/length
   - cursor_line: int                 # Line number (1-indexed)
   - number_of_chars: int             # Total character count

2. AccessibilityAnnouncer (New Component)
   - Handles explicit announcements per user decisions
   - Formats messages based on context (character, word, line)
   - Manages announcement timing/debouncing

3. EditorAccessibilityBridge (New Component)
   - Observes editor state changes
   - Posts NSAccessibility notifications
   - Triggers announcements for navigation/editing
```

### Pattern 1: Text Field Role with Attributes
**What:** Expose text editor as accessible text field
**When to use:** Any editable text component
**Example:**
```v
// Source: NSAccessibilityProtocol documentation

pub enum AccessibilityRole {
    // Existing roles...
    text_field  // Editable text field (NEW)
}

pub struct TextFieldAccessibilityNode {
    AccessibilityNode  // Embed base node
pub mut:
    value           string  // NSAccessibilityValueAttribute
    selected_text   string  // NSAccessibilitySelectedTextAttribute
    selected_range  Range   // NSAccessibilitySelectedTextRangeAttribute
    cursor_line     int     // NSAccessibilityInsertionPointLineNumberAttribute
    num_characters  int     // NSAccessibilityNumberOfCharactersAttribute
}

pub struct Range {
pub:
    location int  // Start position (NSNotFound if no selection)
    length   int  // Range length (0 if no selection)
}

// Update backend to expose these attributes
fn (mut b DarwinAccessibilityBackend) set_text_field_attributes(elem Id, node TextFieldNode) {
    unsafe {
        // Set value (text content)
        value_ns := ns_string(node.value)
        C.v_msgSend_void_id(elem, sel_register_name('setAccessibilityValue:'), value_ns)

        // Set selected text
        if node.selected_range.length > 0 {
            sel_text_ns := ns_string(node.selected_text)
            C.v_msgSend_void_id(elem, sel_register_name('setAccessibilitySelectedText:'),
                sel_text_ns)
        }

        // Set selected range (as NSRange)
        ns_range := make_ns_range(node.selected_range.location, node.selected_range.length)
        C.v_msgSend_void_nsrange(elem, sel_register_name('setAccessibilitySelectedTextRange:'),
            ns_range)

        // Set number of characters
        num_chars_ns := ns_number_int(node.num_characters)
        C.v_msgSend_void_id(elem, sel_register_name('setAccessibilityNumberOfCharacters:'),
            num_chars_ns)

        // Set cursor line number (1-indexed)
        line_ns := ns_number_int(node.cursor_line)
        C.v_msgSend_void_id(elem,
            sel_register_name('setAccessibilityInsertionPointLineNumber:'), line_ns)
    }
}
```

### Pattern 2: Notification Posting on State Changes
**What:** Post NSAccessibility notifications when editor state changes
**When to use:** After cursor moves, selection changes, text mutates
**Example:**
```v
// Source: Apple Accessibility Programming Guide, Chromium implementation

pub struct EditorAccessibilityBridge {
mut:
    am             &AccessibilityManager
    text_field_id  int
    last_cursor    int = -1
    last_selection Range
    last_text      string
}

// Call after cursor movement
pub fn (mut bridge EditorAccessibilityBridge) notify_cursor_moved(new_pos int, text string,
    layout Layout) {
    if new_pos == bridge.last_cursor { return }

    // Update node attributes
    line, _ := calc_line_col(layout, new_pos)
    bridge.am.update_text_field(bridge.text_field_id, text, Range{new_pos, 0}, line)

    // Post notification (VoiceOver detects cursor moved)
    bridge.post_notification(.selected_text_changed)

    bridge.last_cursor = new_pos
}

// Call after selection changes
pub fn (mut bridge EditorAccessibilityBridge) notify_selection_changed(cursor int, anchor int,
    text string, layout Layout) {
    sel_start := if anchor < cursor { anchor } else { cursor }
    sel_length := if anchor < cursor { cursor - anchor } else { anchor - cursor }
    new_range := Range{sel_start, sel_length}

    if new_range == bridge.last_selection { return }

    // Update node attributes
    line, _ := calc_line_col(layout, cursor)
    bridge.am.update_text_field(bridge.text_field_id, text, new_range, line)

    // Post notification
    bridge.post_notification(.selected_text_changed)

    bridge.last_selection = new_range
}

// Call after text mutation
pub fn (mut bridge EditorAccessibilityBridge) notify_text_changed(text string, cursor int,
    layout Layout) {
    if text == bridge.last_text { return }

    // Update node attributes
    line, _ := calc_line_col(layout, cursor)
    bridge.am.update_text_field(bridge.text_field_id, text, Range{cursor, 0}, line)

    // Post notification (VoiceOver announces change)
    bridge.post_notification(.value_changed)

    bridge.last_text = text
}

fn (mut bridge EditorAccessibilityBridge) post_notification(notif AccessibilityNotification) {
    bridge.am.backend.post_notification(bridge.text_field_id, notif)
}
```

### Pattern 3: Announcement Helper for Explicit Feedback
**What:** Provide auditory feedback for navigation/editing per user decisions
**When to use:** Character typed, word jumped, line boundary reached
**Example:**
```v
// Source: User decisions from CONTEXT.md, iOS announcement patterns

pub struct AccessibilityAnnouncer {
mut:
    last_announcement_time i64  // For debouncing
    debounce_ms            i64 = 150  // Prevent excessive announcements
}

// Character navigation announcement (per CONTEXT.md: character only, no phonetic)
pub fn (mut ann AccessibilityAnnouncer) announce_character(ch rune) {
    if !ann.should_announce() { return }

    message := match ch {
        ` ` { 'space' }
        `\t` { 'tab' }
        `\n` { 'newline' }
        `.` { 'period' }
        `,` { 'comma' }
        `;` { 'semicolon' }
        `:` { 'colon' }
        `!` { 'exclamation' }
        `?` { 'question' }
        else { ch.str() }  // Plain character (no phonetic spelling)
    }

    ann.post_announcement(message)
}

// Word jump announcement (per CONTEXT.md: word only, no position context)
pub fn (mut ann AccessibilityAnnouncer) announce_word_jump(word string) {
    if !ann.should_announce() { return }
    ann.post_announcement(word)  // Just the word, no "moved to" prefix
}

// Line boundary announcement (per CONTEXT.md: announce when reached)
pub fn (mut ann AccessibilityAnnouncer) announce_line_boundary(boundary LineBoundary,
    line_num int) {
    if !ann.should_announce() { return }

    message := match boundary {
        .beginning { 'beginning of line' }
        .end { 'end of line' }
    }

    ann.post_announcement(message)
}

// Line number announcement (per CONTEXT.md: always announce on line change)
pub fn (mut ann AccessibilityAnnouncer) announce_line_number(line int) {
    if !ann.should_announce() { return }
    ann.post_announcement('line ${line}')
}

// Document boundary announcement (per CONTEXT.md: announce when reached)
pub fn (mut ann AccessibilityAnnouncer) announce_document_boundary(boundary DocBoundary) {
    if !ann.should_announce() { return }

    message := match boundary {
        .beginning { 'beginning of document' }
        .end { 'end of document' }
    }

    ann.post_announcement(message)
}

// Selection announcement (per CONTEXT.md: read short, count long)
pub fn (mut ann AccessibilityAnnouncer) announce_selection(selected_text string) {
    if !ann.should_announce() { return }

    // Threshold: ~20 characters (user decision)
    if selected_text.len <= 20 {
        ann.post_announcement(selected_text)  // Read the actual text
    } else {
        char_count := selected_text.runes().len
        ann.post_announcement('${char_count} characters selected')
    }
}

// Selection extension announcement (per CONTEXT.md: announce new content)
pub fn (mut ann AccessibilityAnnouncer) announce_selection_extended(added_text string) {
    if !ann.should_announce() { return }
    ann.post_announcement('added: ${added_text}')
}

// Selection cleared announcement (per CONTEXT.md: announce deselected)
pub fn (mut ann AccessibilityAnnouncer) announce_selection_cleared() {
    if !ann.should_announce() { return }
    ann.post_announcement('deselected')
}

// IME composition cancelled (per CONTEXT.md: announce cancellation)
pub fn (mut ann AccessibilityAnnouncer) announce_composition_cancelled() {
    if !ann.should_announce() { return }
    ann.post_announcement('composition cancelled')
}

// Debouncing check
fn (mut ann AccessibilityAnnouncer) should_announce() bool {
    now := time.now().unix_milli()
    if now - ann.last_announcement_time < ann.debounce_ms {
        return false  // Too soon, skip
    }
    ann.last_announcement_time = now
    return true
}

// Post announcement to VoiceOver
// Note: macOS lacks direct announcement API, use workaround
fn (mut ann AccessibilityAnnouncer) post_announcement(message string) {
    // Workaround: Update hidden element's value + post notification
    // Or use NSAccessibilitySpeech (non-standard)
    // Implementation depends on backend capability

    // For now: log for debugging, backend will implement actual announcement
    eprintln('[VoiceOver] ${message}')
}
```

### Pattern 4: Editor Integration
**What:** Wire accessibility into editor event loop
**When to use:** editor_demo.v, any text editor using VGlyph
**Example:**
```v
// Source: Extending editor_demo.v

@[heap]
struct EditorState {
    // Existing fields...
    text       string
    cursor_idx int
    anchor_idx int
    layout     Layout

    // Accessibility support (NEW)
    a11y_bridge    EditorAccessibilityBridge
    a11y_announcer AccessibilityAnnouncer
}

fn event(e &gg.Event, state_ptr voidptr) {
    mut state := unsafe { &EditorState(state_ptr) }

    match e.typ {
        .key_down {
            prev_cursor := state.cursor_idx
            prev_line, _ := calc_line_col(state.layout, prev_cursor)

            // Handle navigation (existing logic)...
            match e.key_code {
                .left {
                    if cmd_held {
                        // Word left
                        state.cursor_idx = state.layout.move_cursor_word_left(state.cursor_idx)
                        word := get_word_at(state.layout, state.cursor_idx)
                        state.a11y_announcer.announce_word_jump(word)  // NEW
                    } else {
                        // Character left
                        state.cursor_idx = state.layout.move_cursor_left(state.cursor_idx)
                        if state.cursor_idx < state.text.len {
                            ch := state.text[state.cursor_idx]
                            state.a11y_announcer.announce_character(ch)  // NEW
                        }
                    }
                }
                .home {
                    state.cursor_idx = state.layout.move_cursor_line_start(state.cursor_idx)
                    state.a11y_announcer.announce_line_boundary(.beginning, prev_line)  // NEW
                }
                .end {
                    state.cursor_idx = state.layout.move_cursor_line_end(state.cursor_idx)
                    state.a11y_announcer.announce_line_boundary(.end, prev_line)  // NEW
                }
                else {}
            }

            // Check line change
            new_line, _ := calc_line_col(state.layout, state.cursor_idx)
            if new_line != prev_line {
                state.a11y_announcer.announce_line_number(new_line)  // NEW
            }

            // Notify cursor moved
            state.a11y_bridge.notify_cursor_moved(state.cursor_idx, state.text,
                state.layout)  // NEW
        }
        .char {
            // Character inserted (existing logic)...
            result := vglyph.insert_text(state.text, state.cursor_idx, char_str)
            state.text = result.new_text
            state.cursor_idx = result.cursor_pos

            // Announce character typed
            state.a11y_announcer.announce_character(char_rune)  // NEW

            // Notify text changed
            state.a11y_bridge.notify_text_changed(state.text, state.cursor_idx,
                state.layout)  // NEW
        }
        else {}
    }
}
```

### Anti-Patterns to Avoid
- **Announcing everything:** Too chatty = frustrating. Follow user verbosity decisions.
- **No debouncing:** Rapid key repeats cause announcement pile-up.
- **Announcing without notification:** Update attributes AND post notification, not just one.
- **Forgetting line numbers:** VoiceOver users rely on line context for navigation.
- **Breaking on selection:** selectedRange must return valid range even when no selection.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Phonetic spelling | Manual 'A' -> 'Alpha' | VoiceOver built-in | System handles per user prefs |
| Announcement timing | Custom throttle logic | 150ms debounce | Screen reader research standard |
| Text-to-speech | Custom voice synthesis | VoiceOver announcements | Consistent voice/rate |
| Accessibility tree diffing | Manual delta tracking | NSAccessibility | System optimizes updates |

**Key insight:** VoiceOver has decades of UX research on verbosity, timing, feedback. Don't recreate,
follow conventions.

## Common Pitfalls

### Pitfall 1: Missing selectedTextRange When No Selection
**What goes wrong:** VoiceOver shows no cursor position
**Why it happens:** Returning nil/none instead of {cursor, 0}
**How to avoid:** Always return valid Range, use length=0 for no selection
**Warning signs:** VoiceOver doesn't announce cursor position

### Pitfall 2: Announcing Too Much
**What goes wrong:** User frustration, can't keep up with announcements
**Why it happens:** Announcing every property change
**How to avoid:** Follow user decisions: character only, word only, boundaries only
**Warning signs:** VoiceOver constantly talking, user can't focus

### Pitfall 3: Not Debouncing Announcements
**What goes wrong:** Rapid key repeats cause announcement pile-up
**Why it happens:** No timing checks between announcements
**How to avoid:** 150ms debounce per screen reader research
**Warning signs:** Announcements overlap, delayed feedback

### Pitfall 4: Forgetting Line Number Updates
**What goes wrong:** VoiceOver doesn't announce line changes
**Why it happens:** Only tracking cursor byte position, not line number
**How to avoid:** Calculate line number on every cursor move, announce when changed
**Warning signs:** User lost in document, no line context

### Pitfall 5: Wrong Notification Type
**What goes wrong:** VoiceOver doesn't track changes correctly
**Why it happens:** Using generic notification instead of text-specific
**How to avoid:** Use selectedTextChanged for cursor/selection, valueChanged for content
**Warning signs:** VoiceOver doesn't respond to edits

### Pitfall 6: Coordinate Space Mismatch
**What goes wrong:** Cursor position reported wrong to VoiceOver
**Why it happens:** Mixing layout-relative vs screen coordinates
**How to avoid:** Always convert to screen coords for accessibility APIs
**Warning signs:** VoiceOver highlights wrong area

## Code Examples

### Complete Accessibility Integration
```v
// Source: Combining patterns above with editor_demo.v

// Initialize accessibility in editor setup
fn init(state_ptr voidptr) {
    mut state := unsafe { &EditorState(state_ptr) }

    // Existing initialization...
    state.ts = vglyph.new_text_system(mut state.gg_ctx) or { panic(err) }

    // NEW: Initialize accessibility
    state.ts.enable_accessibility(true)

    // Create text field accessibility node
    text_field_id := state.ts.create_text_field_node(gg.Rect{50, 50, 700, 500})

    state.a11y_bridge = EditorAccessibilityBridge{
        am: state.ts.accessibility_manager
        text_field_id: text_field_id
    }
    state.a11y_announcer = AccessibilityAnnouncer{}

    // Initial state
    state.a11y_bridge.notify_text_changed(state.text, state.cursor_idx, state.layout)
}

// Frame update includes accessibility
fn frame(state_ptr voidptr) {
    mut state := unsafe { &EditorState(state_ptr) }

    state.gg_ctx.begin()

    // Draw text (existing)...
    state.ts.draw_text(offset_x, offset_y, state.text, state.cfg) or {}

    // Draw cursor (existing)...

    state.gg_ctx.end()

    // Commit accessibility tree (NEW)
    state.ts.commit_accessibility()
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Over-verbose announcements | Context-aware verbosity | Continuous UX research | Less fatigue |
| Manual phonetic spelling | System phonetics | Always | Respects user prefs |
| Separate accessibility tree | Integrated with rendering | Modern editors | Less desync |
| Poll-based state | Notification-based | macOS 10.10+ | Lower latency |

**Deprecated/outdated:**
- Carbon Accessibility APIs: Replaced by NSAccessibility in Cocoa
- Over-the-spot announcements: Inline preferred for editors

## Open Questions

1. **macOS announcement API?**
   - What we know: No direct NSAccessibilityAnnouncementNotification like iOS
   - What's unclear: Best workaround (hidden element, private API, alternative)
   - Recommendation: Start with notification-only approach, add announcements if needed

2. **Emoji short name source?**
   - What we know: User wants 'grinning face' not full Unicode name
   - What's unclear: Reliable lookup table/library
   - Recommendation: Use Unicode CLDR short names if available

3. **IME composition feedback format?**
   - What we know: User deferred preedit announcement format to Claude
   - What's unclear: Explicit 'composing:' prefix vs plain text
   - Recommendation: Test with VoiceOver users, start with prefix

4. **Integration with existing accessibility tree?**
   - What we know: VGlyph has AccessibilityManager for static text
   - What's unclear: How to handle editable field vs read-only text nodes
   - Recommendation: Text field replaces static text nodes when editing active

## Sources

### Primary (HIGH confidence)
- [NSAccessibilityProtocol Documentation](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol)
  - Protocol requirements
- [NSAccessibility Standard Attributes](https://developer.apple.com/documentation/appkit/accessibility_for_macos/nsaccessibility/standard_attributes)
  - Attribute list
- [NSAccessibility.Notification Documentation](https://developer.apple.com/documentation/appkit/nsaccessibility/notification)
  - Notification types
- VGlyph accessibility/manager.v - Existing infrastructure
- VGlyph accessibility/backend_darwin.v - Native bindings

### Secondary (MEDIUM confidence)
- [AppleVis VoiceOver Verbosity Guide](https://www.applevis.com/guides/guide-verbosity-options-macos-voiceover)
  - User preferences
- [Apple Support: VoiceOver Verbosity](https://support.apple.com/guide/voiceover/announcements-tab-cpvouverbann/mac)
  - Announcement settings
- [Deque: Dynamic Notifications](https://www.deque.com/blog/dynamic-notifications/) - Timing guidance
  (150-200ms threshold)
- [VA.gov: When Screen Reader Needs Announcement](https://design.va.gov/accessibility/when-a-screen-reader-needs-to-announce-content)
  - Best practices
- [Chromium Accessibility Overview](https://chromium.googlesource.com/chromium/src/+/main/docs/accessibility/overview.md)
  - Implementation patterns
- WebSearch: VoiceOver text editing patterns - Community experience

### Tertiary (LOW confidence)
- [AppleVis: Text Editing Disaster](https://www.applevis.com/forum/macos-mac-apps/text-editing-mac-total-disaster-discuss)
  - Known issues (spellcheck, paragraph nav broken)
- iOS UIAccessibility patterns - Cross-platform reference (different API, similar concepts)

## Metadata

**Confidence breakdown:**
- NSAccessibility protocol/attributes: HIGH - Apple documentation, existing VGlyph impl
- Notification patterns: HIGH - Apple docs, Chromium reference
- Announcement verbosity: MEDIUM - User decisions clear, implementation details fuzzy
- macOS announcement workaround: LOW - No official API, needs experimentation

**Research date:** 2026-02-03
**Valid until:** 2026-03-03 (30 days - macOS APIs stable, VoiceOver conventions evolve slowly)
