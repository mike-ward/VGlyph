module accessibility

// Stub implementation for non-macOS platforms.
// This ensures that the code compiles on Windows and Linux without
// requiring platform-specific dependencies.

@[if !darwin]
struct StubAccessibilityBackend {}

fn (mut b StubAccessibilityBackend) update_tree(nodes map[int]AccessibilityNode, root_id int) {
	// Do nothing on unsupported platforms.
}

fn (mut b StubAccessibilityBackend) set_focus(node_id int) {
	// Do nothing
}

fn (mut b StubAccessibilityBackend) post_notification(node_id int,
	notification AccessibilityNotification) {
	// Do nothing
}

fn (mut b StubAccessibilityBackend) update_text_field(node_id int, value string,
	selected_range Range, cursor_line int) {
	// Do nothing
}
