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

	imgui.PushStyleColor(
		imgui.Col.WindowBg,
		imgui.GetColorU32ImVec4(
			imgui.Vec4{0.05, 0.05, 0.05, 1.0} if state.game_focused else imgui.Vec4{0.1, 0.1, 0.1, 1.0},
		),
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

			imgui.SeparatorText("Load Texture Atlas")

			// FIX: These cstrings are recreated every frame, causing the input text to reset.
			filepath: cstring = strings.clone_to_cstring("")
			name: cstring = strings.clone_to_cstring("")

			imgui.InputText(strings.clone_to_cstring("Source##atlas_path"), filepath, 256)
			imgui.InputText(strings.clone_to_cstring("Name##atlas_name"), name, 64)

			if imgui.Button("Load Atlas") {
				state.event_handlers["load_atlas"](state, string(filepath), string(name))
			}

			imgui.TreePop()
		}

		if (imgui.TreeNode("Add Object")) {
			imgui.InputText(
				strings.clone_to_cstring("Source##object_path"),
				state.add_object.texture_source,
				256,
			)
			imgui.InputFloat2(
				strings.clone_to_cstring("Position##object_position"),
				&state.add_object.position,
			)

			if imgui.Button("Add Object") {
				state.event_handlers["add_object"](state)
			}

			imgui.TreePop()
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

	imgui.PopStyleColor(1)
}
