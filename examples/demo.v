module main

import gg
import text_render

struct App {
mut:
	ctx      &gg.Context
	tr_ctx   &text_render.Context
	renderer &text_render.Renderer
	layout   text_render.Layout
}

fn main() {
	mut app := &App{
		ctx:      unsafe { nil }
		tr_ctx:   unsafe { nil }
		renderer: unsafe { nil }
	}

	app.ctx = gg.new_context(
		width:         800
		height:        600
		bg_color:      gg.gray
		create_window: true
		window_title:  'V Text Render Atlas Demo'
		frame_fn:      frame
		user_data:     app
		init_fn:       init
	)

	app.ctx.run()
	app.tr_ctx.free()
}

fn init(mut app App) {
	app.tr_ctx = text_render.new_context() or { panic(err) }

	// Text containing Latin, Arabic, CJK, and Emojis
	text := 'Hello السلام Verden 🌍 9局て脂済事つまきな政98院'

	// Pango handles font fallback automatically.
	// We just ask for a base font and size.
	// Ensure you have fonts installed that cover these scripts (e.g. Noto Sans).
	app.layout = app.tr_ctx.layout_text(text, 'Sans 30') or { panic(err.msg()) }

	app.renderer = text_render.new_renderer(mut app.ctx)
}

fn frame(mut app App) {
	app.ctx.begin()

	if unsafe { app.renderer != 0 } {
		app.renderer.draw_layout(app.layout, 0, 0)
	}

	app.ctx.end()
}
