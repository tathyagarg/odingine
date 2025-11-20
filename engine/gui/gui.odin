package gui

import imgui "../../third_party/imgui"

show_gui :: proc(window_width: u32, window_height: u32) {
	imgui.SetNextWindowPos(imgui.Vec2{0, 0}, imgui.Cond.Always)
	imgui.SetNextWindowSize(
		imgui.Vec2{f32(window_width / 6), f32(window_height)},
		imgui.Cond.Always,
	)
	if imgui.Begin("Test Window", nil, {.NoMove, .NoResize, .NoCollapse}) {
		imgui.Text("Hello, world!")
	}
	imgui.End()

	imgui.SetNextWindowPos(
		imgui.Vec2{f32(window_width / 6), f32(2 * window_height / 3)},
		imgui.Cond.Always,
	)
	imgui.SetNextWindowSize(
		imgui.Vec2{f32(2 * window_width / 3), f32(window_height / 3)},
		imgui.Cond.Always,
	)
	if imgui.Begin("Another Window", nil, {.NoMove, .NoResize, .NoCollapse}) {
		imgui.Text("This is another window.")
	}
	imgui.End()
}
