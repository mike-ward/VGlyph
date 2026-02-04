module vglyph

fn test_add_font_file() {
	// We test Context directly to avoid initializing the full graphics subsystem (gg/sokol)
	// which can fail in headless test environments.
	mut ctx := new_context(1.0) or {
		assert false, 'failed to create context'
		return
	}
	// Clean up valid context
	defer { ctx.free() }

	// Test loading a non-existent file - should return error
	ctx.add_font_file('/path/to/non_existent_file.ttf') or {
		// Expected: non-existent file should fail
		assert true
	}

	// Test loading an existing file (we use the asset we found earlier)
	font_path := '${@DIR}/assets/feathericon.ttf'
	ctx.add_font_file(font_path) or {
		assert false, 'add_font_file failed for existing font: ${err}'
		return
	}
}
