module vglyph

import gg

fn test_lerp_color_endpoints() {
	a := gg.Color{0, 0, 0, 255}
	b := gg.Color{255, 255, 255, 255}

	c0 := lerp_color(a, b, 0.0)
	assert c0.r == 0
	assert c0.g == 0
	assert c0.b == 0
	assert c0.a == 255

	c1 := lerp_color(a, b, 1.0)
	assert c1.r == 255
	assert c1.g == 255
	assert c1.b == 255
	assert c1.a == 255
}

fn test_lerp_color_midpoint() {
	a := gg.Color{0, 0, 0, 0}
	b := gg.Color{200, 100, 50, 250}

	c := lerp_color(a, b, 0.5)
	assert c.r == 100
	assert c.g == 50
	assert c.b == 25
	assert c.a == 125
}

fn test_lerp_color_clamps_t() {
	a := gg.Color{10, 20, 30, 40}
	b := gg.Color{110, 120, 130, 140}

	// t < 0 clamps to 0
	c_neg := lerp_color(a, b, -5.0)
	assert c_neg.r == a.r
	assert c_neg.g == a.g

	// t > 1 clamps to 1
	c_over := lerp_color(a, b, 10.0)
	assert c_over.r == b.r
	assert c_over.g == b.g
}

fn test_gradient_color_at_empty_stops() {
	stops := []GradientStop{}
	c := gradient_color_at(stops, 0.5)
	assert c.r == 0
	assert c.g == 0
	assert c.b == 0
	assert c.a == 255
}

fn test_gradient_color_at_single_stop() {
	stops := [
		GradientStop{
			color:    gg.Color{100, 150, 200, 255}
			position: 0.5
		},
	]
	// Any t should return the single stop color
	c0 := gradient_color_at(stops, 0.0)
	assert c0.r == 100
	c1 := gradient_color_at(stops, 1.0)
	assert c1.r == 100
}

fn test_gradient_color_at_two_stops() {
	stops := [
		GradientStop{
			color:    gg.Color{0, 0, 0, 255}
			position: 0.0
		},
		GradientStop{
			color:    gg.Color{200, 100, 50, 255}
			position: 1.0
		},
	]

	c_mid := gradient_color_at(stops, 0.5)
	assert c_mid.r == 100
	assert c_mid.g == 50
	assert c_mid.b == 25
}

fn test_gradient_color_at_four_stops() {
	stops := [
		GradientStop{
			color:    gg.Color{255, 0, 0, 255}
			position: 0.0
		},
		GradientStop{
			color:    gg.Color{0, 255, 0, 255}
			position: 0.33
		},
		GradientStop{
			color:    gg.Color{0, 0, 255, 255}
			position: 0.66
		},
		GradientStop{
			color:    gg.Color{255, 255, 255, 255}
			position: 1.0
		},
	]

	// At stop positions, return exact color
	c0 := gradient_color_at(stops, 0.0)
	assert c0.r == 255
	assert c0.g == 0

	c1 := gradient_color_at(stops, 0.33)
	assert c1.r == 0
	assert c1.g == 255

	c3 := gradient_color_at(stops, 1.0)
	assert c3.r == 255
	assert c3.g == 255
	assert c3.b == 255
}

fn test_gradient_color_at_before_first_stop() {
	stops := [
		GradientStop{
			color:    gg.Color{50, 100, 150, 200}
			position: 0.3
		},
		GradientStop{
			color:    gg.Color{200, 200, 200, 255}
			position: 0.8
		},
	]
	// t before first stop returns first stop color
	c := gradient_color_at(stops, 0.0)
	assert c.r == 50
	assert c.g == 100
}

fn test_gradient_color_at_after_last_stop() {
	stops := [
		GradientStop{
			color:    gg.Color{50, 100, 150, 200}
			position: 0.2
		},
		GradientStop{
			color:    gg.Color{200, 200, 200, 255}
			position: 0.7
		},
	]
	// t after last stop returns last stop color
	c := gradient_color_at(stops, 1.0)
	assert c.r == 200
	assert c.a == 255
}

fn test_gradient_color_at_coincident_positions() {
	stops := [
		GradientStop{
			color:    gg.Color{255, 0, 0, 255}
			position: 0.5
		},
		GradientStop{
			color:    gg.Color{0, 0, 255, 255}
			position: 0.5
		},
	]
	// Coincident stops (span=0): returns first stop color
	c := gradient_color_at(stops, 0.5)
	assert c.r == 255
	assert c.b == 0
}
