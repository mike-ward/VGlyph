// stress_validation.v validates profiling metrics under multilingual stress.
//
// This is a profiling tool for measuring LayoutCache hit rate, atlas
// utilization, and async vs sync upload performance with 2000+ glyphs
// across 8+ scripts.
//
// Run: v -d profile run examples/stress_validation.v
module main

import gg
import vglyph

struct App {
mut:
	ctx                  &gg.Context        = unsafe { nil }
	ts                   &vglyph.TextSystem = unsafe { nil }
	frame_count          int
	measurements_printed bool
}

// generate_multilingual_text creates text with 2000+ unique glyphs across 8+ scripts.
fn generate_multilingual_text() []string {
	mut texts := []string{}

	// ASCII: full printable range (0x21-0x7E, ~94 chars)
	mut ascii := ''
	for i in 0x21 .. 0x7F {
		ascii += rune(i).str()
	}
	texts << 'ASCII: ${ascii}'

	// Latin Extended: accented chars (0xC0-0xFF, ~64 chars)
	mut latin := ''
	for i in 0xC0 .. 0x100 {
		latin += rune(i).str()
	}
	texts << 'Latin Extended: ${latin}'

	// Greek: (0x0391-0x03C9, ~50 chars)
	mut greek := ''
	for i in 0x0391 .. 0x03CA {
		greek += rune(i).str()
	}
	texts << 'Greek: ${greek}'

	// Cyrillic: (0x0410-0x044F, ~64 chars)
	mut cyrillic := ''
	for i in 0x0410 .. 0x0450 {
		cyrillic += rune(i).str()
	}
	texts << 'Cyrillic: ${cyrillic}'

	// Arabic: (0x0621-0x064A, ~40 chars)
	mut arabic := ''
	for i in 0x0621 .. 0x064B {
		arabic += rune(i).str()
	}
	texts << 'Arabic: ${arabic}'

	// Devanagari: (0x0901-0x0939, ~50 chars)
	mut devanagari := ''
	for i in 0x0901 .. 0x093A {
		devanagari += rune(i).str()
	}
	texts << 'Devanagari: ${devanagari}'

	// CJK: common ideographs (0x4E00-0x4FFF, ~256 chars split into chunks)
	for chunk in 0 .. 4 {
		start := 0x4E00 + (chunk * 64)
		end := start + 64
		mut cjk := ''
		for i in start .. end {
			cjk += rune(i).str()
		}
		texts << 'CJK${chunk}: ${cjk}'
	}

	// Hangul: syllables (0xAC00-0xAC80, ~128 chars)
	mut hangul := ''
	for i in 0xAC00 .. 0xAC80 {
		hangul += rune(i).str()
	}
	texts << 'Hangul: ${hangul}'

	// Emoji: diverse set (~30 emoji)
	texts << 'Emoji: 😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🤩'

	return texts
}

fn frame(mut app App) {
	app.ctx.begin()
	app.ctx.draw_rect_filled(0, 0, app.ctx.width, app.ctx.height, gg.white)

	texts := generate_multilingual_text()

	// Render with two font sizes for atlas diversity
	cfg_large := vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Sans 20'
			color:     gg.black
		}
	}
	cfg_small := vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Sans 14'
			color:     gg.rgb(60, 60, 60)
		}
	}

	// Grid layout
	mut y := f32(20)
	for i, text in texts {
		cfg := if i % 2 == 0 { cfg_large } else { cfg_small }
		app.ts.draw_text(20, y, text, cfg) or { continue }
		y += if i % 2 == 0 { f32(30) } else { f32(25) }
	}

	$if profile ? {
		// Three-pass measurement
		if app.frame_count == 100 {
			// Pass 1 complete (warmup), reset for Pass 2 (async)
			app.ts.reset_profile_metrics()
		} else if app.frame_count == 200 {
			// Pass 2 complete (async), print results
			metrics_async := app.ts.get_profile_metrics()
			println('=== Async Upload Mode ===')
			metrics_async.print_summary()
			println('LayoutCache hit rate: ${metrics_async.layout_cache_hit_rate():.1}%')
			println('Atlas utilization: ${metrics_async.atlas_utilization():.1}%')
			println('Upload time: ${metrics_async.upload_time_ns / 1000} us')
			println('')

			// Switch to sync mode for Pass 3
			app.ts.set_async_uploads(false)
			app.ts.reset_profile_metrics()
		} else if app.frame_count == 300 && !app.measurements_printed {
			// Pass 3 complete (sync), print results
			metrics_sync := app.ts.get_profile_metrics()
			println('=== Sync Upload Mode ===')
			metrics_sync.print_summary()
			println('LayoutCache hit rate: ${metrics_sync.layout_cache_hit_rate():.1}%')
			println('Atlas utilization: ${metrics_sync.atlas_utilization():.1}%')
			println('Upload time: ${metrics_sync.upload_time_ns / 1000} us')
			println('')

			app.measurements_printed = true
			// Request quit after measurements
			C.sapp_request_quit()
		}
	}

	// Status display
	status := 'Frame: ${app.frame_count} | Phase: ${if app.frame_count < 100 {
		'Warmup'
	} else if app.frame_count < 200 {
		'Async'
	} else if app.frame_count < 300 {
		'Sync'
	} else {
		'Done'
	}}'
	app.ts.draw_text(20, 5, status, vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'Sans 16'
			color:     gg.red
		}
	}) or {}

	app.ts.commit()
	app.ctx.end()
	app.frame_count++
}

fn init(mut app App) {
	app.ts = vglyph.new_text_system(mut app.ctx) or { panic(err) }
}

fn main() {
	mut app := &App{}
	app.ctx = gg.new_context(
		width:         1200
		height:        800
		window_title:  'Stress Validation: 2000+ Multilingual Glyphs'
		create_window: true
		bg_color:      gg.white
		ui_mode:       false
		user_data:     app
		frame_fn:      frame
		init_fn:       init
	)

	app.ctx.run()
}
