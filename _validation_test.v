module vglyph

import os

fn test_validate_text_valid() {
	// Normal UTF-8 should pass
	result := validate_text_input('Hello, World!', 1024, 'test') or {
		assert false, 'Valid text should not error: ${err}'
		return
	}
	assert result == 'Hello, World!'
}

fn test_validate_text_valid_unicode() {
	// Multi-byte UTF-8 (CJK, emoji) should pass
	result := validate_text_input('Hello', 1024, 'test') or {
		assert false, 'Valid unicode should not error: ${err}'
		return
	}
	assert result.len > 0
}

fn test_validate_text_invalid_utf8() {
	// Invalid UTF-8 bytes should be rejected
	invalid_bytes := [u8(0xff), 0xfe].bytestr()
	validate_text_input(invalid_bytes, 1024, 'test') or {
		assert err.msg().contains('invalid UTF-8')
		return
	}
	assert false, 'Invalid UTF-8 should error'
}

fn test_validate_text_empty() {
	// Empty string should be rejected
	validate_text_input('', 1024, 'test') or {
		assert err.msg().contains('empty string')
		return
	}
	assert false, 'Empty string should error'
}

fn test_validate_text_too_long() {
	// Text exceeding limit should be rejected
	long_text := 'x'.repeat(2000)
	validate_text_input(long_text, 1000, 'test') or {
		assert err.msg().contains('exceeds max')
		return
	}
	assert false, 'Too long text should error'
}

fn test_validate_path_valid() {
	// Create temp file to test valid path
	tmp_path := os.temp_dir() + '/vglyph_test_font.ttf'
	os.write_file(tmp_path, 'dummy') or { return }
	defer { os.rm(tmp_path) or {} }

	result := validate_font_path(tmp_path, 'test') or {
		assert false, 'Valid path should not error: ${err}'
		return
	}
	assert result == tmp_path
}

fn test_validate_path_traversal() {
	// Path with ".." should be rejected
	validate_font_path('/fonts/../etc/passwd', 'test') or {
		assert err.msg().contains('path traversal')
		return
	}
	assert false, 'Path traversal should error'
}

fn test_validate_path_nonexistent() {
	// Non-existent path should be rejected
	validate_font_path('/nonexistent/path/to/font.ttf', 'test') or {
		assert err.msg().contains('does not exist')
		return
	}
	assert false, 'Nonexistent path should error'
}

fn test_validate_path_empty() {
	// Empty path should be rejected
	validate_font_path('', 'test') or {
		assert err.msg().contains('empty font path')
		return
	}
	assert false, 'Empty path should error'
}

fn test_validate_size_valid() {
	// Size within bounds should pass
	result := validate_size(12.0, 0.1, 500.0, 'font size', 'test') or {
		assert false, 'Valid size should not error: ${err}'
		return
	}
	assert result == 12.0
}

fn test_validate_size_bounds() {
	// Size below minimum should be rejected
	validate_size(0.05, 0.1, 500.0, 'font size', 'test') or {
		assert err.msg().contains('out of range')
		return
	}
	assert false, 'Size below min should error'
}

fn test_validate_size_above_max() {
	// Size above maximum should be rejected
	validate_size(600.0, 0.1, 500.0, 'font size', 'test') or {
		assert err.msg().contains('out of range')
		return
	}
	assert false, 'Size above max should error'
}

fn test_validate_dimension_valid() {
	// Valid dimension should pass
	result := validate_dimension(1024, 'width', 'test') or {
		assert false, 'Valid dimension should not error: ${err}'
		return
	}
	assert result == 1024
}

fn test_validate_dimension_zero() {
	// Zero dimension should be rejected
	validate_dimension(0, 'width', 'test') or {
		assert err.msg().contains('must be positive')
		return
	}
	assert false, 'Zero dimension should error'
}

fn test_validate_dimension_negative() {
	// Negative dimension should be rejected
	validate_dimension(-100, 'height', 'test') or {
		assert err.msg().contains('must be positive')
		return
	}
	assert false, 'Negative dimension should error'
}

fn test_validate_dimension_exceeds_max() {
	// Dimension exceeding max should be rejected
	validate_dimension(20000, 'atlas size', 'test') or {
		assert err.msg().contains('exceeds max')
		return
	}
	assert false, 'Dimension exceeding max should error'
}
