package gui

import "core:fmt"
import "core:strings"

import "vendor:glfw"

import imgui "../../third_party/imgui"
import "../../utils"

show_gui :: proc(window_width: u32, window_height: u32, window: glfw.WindowHandle) {
	state := (^utils.DevelopmentState)(glfw.GetWindowUserPointer(window))

	imgui.SetNextWindowPos(imgui.Vec2{0, 0}, imgui.Cond.Always)
	imgui.SetNextWindowSize(
		imgui.Vec2{f32(window_width / 6), f32(window_height)},
		imgui.Cond.Always,
	)
	if imgui.Begin("Test Window", nil, {.NoMove, .NoResize, .NoCollapse}) {
		imgui.Checkbox("Game focused?", &state.game_focused)

		if (imgui.TreeNode("Texture Atlases")) {
			for name, atlas_ptr in state.atlases {
				imgui.SeparatorText(strings.unsafe_string_to_cstring(name))

				if imgui.InputText(
					strings.clone_to_cstring(fmt.aprintf("Source##%s", name)),
					atlas_ptr.header.filename,
					128,
				) {

				}

				if imgui.Button("Save") {
					state.event_handlers["save_atlas"](state)
				}
			}

			imgui.TreePop()
		}

		if imgui.Button("Load Texture Atlas") {

		}
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

	imgui.SetNextWindowPos(imgui.Vec2{f32(5 * window_width / 6), 0}, imgui.Cond.Always)
	imgui.SetNextWindowSize(
		imgui.Vec2{f32(window_width / 6), f32(window_height)},
		imgui.Cond.Always,
	)
	if imgui.Begin("Third Window", nil, {.NoMove, .NoResize, .NoCollapse}) {
		imgui.Text("This is the third window.")
	}
	imgui.End()
}
