// atlas_debug.v demonstrates glyph atlas visualization.
//
// This is a development tool for debugging atlas packing and layout.
//
// Features shown:
// - Glyph atlas texture visualization
// - Atlas population with various scripts
// - get_atlas_image() API usage
//
// Run: v run examples/atlas_debug.v
module main

import gg
import vglyph

struct AppAtlasDebug {
mut:
	ctx         &gg.Context
	text_system &vglyph.TextSystem
}

fn main() {
	mut app := &AppAtlasDebug{
		ctx:         unsafe { nil }
		text_system: unsafe { nil }
	}
	app.ctx = gg.new_context(
		bg_color:      gg.rgb(20, 20, 20)
		width:         900
		height:        950
		create_window: true
		window_title:  'Glyph Atlas Debug'
		frame_fn:      frame
		init_fn:       init
		user_data:     app
	)
	app.ctx.run()
}

fn init(mut app AppAtlasDebug) {
	app.text_system = vglyph.new_text_system(mut app.ctx) or { panic(err) }
}

fn frame(mut app AppAtlasDebug) {
	app.ctx.begin()

	// 1. Draw some text to populate the atlas
	// We'll use a mix of characters to fill it up a bit.
	txt := 'Hello World! This is a test of the glyph atlas.'
	cfg := vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'RobotoMono-Regular 24'
			color:     gg.white
		}
	}
	app.text_system.draw_text(50, 10, txt, cfg) or { panic(err) }

	cfg2 := vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name: 'RobotoMono-Regular 16'
			color:     gg.yellow
		}
	}
	app.text_system.draw_text(50, 60, 'Using different sizes puts more glyphs in the atlas.',
		cfg2) or { panic(err) }

	app.text_system.draw_text(50, 110, 'Symbols: ∑∮∅≃⋘⌨☀☁☂☺₠₣₿₱',
		cfg) or { panic(err) }

	// 4. Add Emojis and Multi-language text
	// Ensure you have fonts installed that cover these, e.g. Noto Color Emoji, Noto Sans CJK
	emoji_text := 'Emojis: 😀 😃 😄 😁 😆 😅 😂 🤣 🤪 👀 🏋️‍♂️ ⛔ 🇺🇸 🇬🇧 🇯🇵 🇰🇷'
	app.text_system.draw_text(50, 160, emoji_text, cfg) or { panic(err) }

	jp_text := 'Japanese: こんにちは世界 (Hello World)'
	app.text_system.draw_text(50, 210, jp_text, cfg) or { panic(err) }

	kr_text := 'Korean: 안녕하세요 세계 (Hello World)'
	app.text_system.draw_text(50, 260, kr_text, cfg) or { panic(err) }

	// 2. Commit text system (uploads atlas to GPU)
	app.text_system.commit()

	// 3. Get and draw the atlas image
	// The atlas is likely 1024x1024 (default in renderer.v).
	// We'll draw it scaled down in the bottom-right or clearly executing functionality.
	atlas_img := app.text_system.get_atlas_image()

	// Draw a background for the atlas visibility
	atlas_x := f32(50)
	atlas_y := f32(380)
	atlas_w := f32(512) // Show it at half size (if 1024)
	atlas_h := f32(512)

	app.ctx.draw_rect_filled(atlas_x - 2, atlas_y - 2, atlas_w + 4, atlas_h + 4, gg.rgb(255,
		0, 0)) // Red border
	app.ctx.draw_rect_filled(atlas_x, atlas_y, atlas_w, atlas_h, gg.black) // Black background

	// Draw the atlas texture
	app.ctx.draw_image_with_config(
		img:      &atlas_img
		img_rect: gg.Rect{
			x:      atlas_x
			y:      atlas_y
			width:  atlas_w
			height: atlas_h
		}
	)

	// Get shelf debug info
	debug_info := app.text_system.get_atlas_debug_info()

	// Calculate scale factor (atlas displayed at 50%)
	scale := atlas_w / f32(debug_info.page_width)

	// Draw shelf boundaries
	for shelf in debug_info.shelves {
		// Shelf top boundary
		shelf_y := atlas_y + f32(shelf.y) * scale
		shelf_h := f32(shelf.height) * scale
		used_w := f32(shelf.used_x) * scale

		// Draw shelf outline (gray, full width)
		app.ctx.draw_rect_empty(atlas_x, shelf_y, atlas_w, shelf_h, gg.rgb(80, 80, 80))

		// Draw used portion (green fill, low alpha)
		app.ctx.draw_rect_filled(atlas_x, shelf_y, used_w, shelf_h, gg.Color{
			r: 0
			g: 255
			b: 0
			a: 40
		})

		// Draw used boundary (bright green line)
		app.ctx.draw_line(atlas_x + used_w, shelf_y, atlas_x + used_w, shelf_y + shelf_h,
			gg.rgb(0, 255, 0))
	}

	// Display utilization percentage
	utilization := if debug_info.total_pixels > 0 {
		f32(debug_info.used_pixels) / f32(debug_info.total_pixels) * 100.0
	} else {
		0.0
	}
	util_text := 'Utilization: ${utilization:.1f}% (${debug_info.shelves.len} shelves)'
	app.ctx.draw_text(int(atlas_x), int(atlas_y + atlas_h + 10), util_text, gg.TextCfg{
		color: gg.white
		size:  14
	})

	app.ctx.draw_text(int(atlas_x), int(atlas_y - 20), 'Glyph Atlas Texture (Scaled 50%):',
		gg.TextCfg{
		color: gg.white
		size:  16
	})

	app.ctx.end()
}
