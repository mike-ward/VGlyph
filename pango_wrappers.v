module vglyph

// Pango RAII Wrappers

pub struct PangoLayout {
pub mut:
	ptr &C.PangoLayout = unsafe { nil }
}

pub fn (p PangoLayout) is_nil() bool {
	return unsafe { p.ptr == nil }
}

pub fn (mut p PangoLayout) free() {
	if !p.is_nil() {
		C.g_object_unref(p.ptr)
		p.ptr = unsafe { nil }
	}
}

pub struct PangoContext {
pub mut:
	ptr &C.PangoContext = unsafe { nil }
}

pub fn (p PangoContext) is_nil() bool {
	return unsafe { p.ptr == nil }
}

pub fn (mut p PangoContext) free() {
	if !p.is_nil() {
		C.g_object_unref(p.ptr)
		p.ptr = unsafe { nil }
	}
}

pub struct PangoAttrList {
pub mut:
	ptr &C.PangoAttrList = unsafe { nil }
}

pub fn (p PangoAttrList) is_nil() bool {
	return unsafe { p.ptr == nil }
}

pub fn (mut p PangoAttrList) free() {
	if !p.is_nil() {
		track_attr_list_free()
		C.pango_attr_list_unref(p.ptr)
		p.ptr = unsafe { nil }
	}
}

pub fn new_pango_attr_list() PangoAttrList {
	track_attr_list_alloc()
	return PangoAttrList{
		ptr: C.pango_attr_list_new()
	}
}

pub struct PangoFontDescription {
pub mut:
	ptr &C.PangoFontDescription = unsafe { nil }
}

pub fn (p PangoFontDescription) is_nil() bool {
	return unsafe { p.ptr == nil }
}

pub fn (mut p PangoFontDescription) free() {
	if !p.is_nil() {
		C.pango_font_description_free(p.ptr)
		p.ptr = unsafe { nil }
	}
}

pub struct PangoFontMap {
pub mut:
	ptr &C.PangoFontMap = unsafe { nil }
}

pub fn (p PangoFontMap) is_nil() bool {
	return unsafe { p.ptr == nil }
}

pub fn (mut p PangoFontMap) free() {
	if !p.is_nil() {
		C.g_object_unref(p.ptr)
		p.ptr = unsafe { nil }
	}
}

pub struct PangoFont {
pub mut:
	ptr &C.PangoFont = unsafe { nil }
}

pub fn (p PangoFont) is_nil() bool {
	return unsafe { p.ptr == nil }
}

pub fn (mut p PangoFont) free() {
	if !p.is_nil() {
		C.g_object_unref(p.ptr)
		p.ptr = unsafe { nil }
	}
}

pub struct PangoLayoutIter {
pub mut:
	ptr &C.PangoLayoutIter = unsafe { nil }
}

pub fn (p PangoLayoutIter) is_nil() bool {
	return unsafe { p.ptr == nil }
}

pub fn (mut p PangoLayoutIter) free() {
	if !p.is_nil() {
		C.pango_layout_iter_free(p.ptr)
		p.ptr = unsafe { nil }
	}
}

pub struct PangoFontMetrics {
pub mut:
	ptr &C.PangoFontMetrics = unsafe { nil }
}

pub fn (p PangoFontMetrics) is_nil() bool {
	return unsafe { p.ptr == nil }
}

pub fn (mut p PangoFontMetrics) free() {
	if !p.is_nil() {
		C.pango_font_metrics_unref(p.ptr)
		p.ptr = unsafe { nil }
	}
}

pub struct PangoTabArray {
pub mut:
	ptr &C.PangoTabArray = unsafe { nil }
}

pub fn (p PangoTabArray) is_nil() bool {
	return unsafe { p.ptr == nil }
}

pub fn (mut p PangoTabArray) free() {
	if !p.is_nil() {
		C.pango_tab_array_free(p.ptr)
		p.ptr = unsafe { nil }
	}
}
