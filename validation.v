module vglyph

import encoding.utf8.validate as utf8_validate
import os

// Maximum text length (10KB) for DoS prevention per RESEARCH.md
const max_text_length = 10240

// Maximum texture dimension (16384 pixels)
const max_texture_dimension = 16384

// Font size bounds
const min_font_size = f32(0.1)
const max_font_size = f32(500.0)

// validate_text_input validates text input for UTF-8 encoding, non-empty, and length limits.
// Returns the text unchanged if valid, error otherwise.
// location: caller identifier for error context (e.g., function name)
pub fn validate_text_input(text string, max_len int, location string) !string {
	if text.len == 0 {
		return error('empty string not allowed at ${location}')
	}

	if text.len > max_len {
		return error('text exceeds max length ${max_len} bytes at ${location}')
	}

	if !utf8_validate.utf8_string(text) {
		return error('invalid UTF-8 encoding at ${location}')
	}

	return text
}

// validate_font_path validates a font file path for safety and existence.
// Returns the path unchanged if valid, error otherwise.
// location: caller identifier for error context
pub fn validate_font_path(path string, location string) !string {
	if path.len == 0 {
		return error('empty font path not allowed at ${location}')
	}

	// Path traversal check
	if path.contains('..') {
		return error('path traversal (..) not allowed in font path at ${location}')
	}

	// Existence check - let FreeType handle format validation per CONTEXT.md
	if !os.exists(path) {
		return error('font file does not exist: "${path}" at ${location}')
	}

	return path
}

// validate_size validates a numeric size value against min/max bounds.
// Returns the size unchanged if valid, error otherwise.
// name: parameter name for error context (e.g., "font size")
// location: caller identifier for error context
pub fn validate_size(size f32, min f32, max f32, name string, location string) !f32 {
	if size < min || size > max {
		return error('${name} ${size} out of range [${min}, ${max}] at ${location}')
	}
	return size
}

// validate_dimension validates an integer dimension (width/height).
// Returns the dimension unchanged if valid, error otherwise.
// name: parameter name for error context (e.g., "atlas width")
// location: caller identifier for error context
pub fn validate_dimension(dim int, name string, location string) !int {
	if dim <= 0 {
		return error('${name} must be positive, got ${dim} at ${location}')
	}

	if dim > max_texture_dimension {
		return error('${name} ${dim} exceeds max ${max_texture_dimension} at ${location}')
	}

	return dim
}
