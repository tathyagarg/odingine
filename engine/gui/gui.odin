package gui

import "core:fmt"
import "core:sort"
import "core:strings"

import "vendor:glfw"

import rendering "../../engine/rendering"
import imgui "../../third_party/imgui"
import "../../utils"

COLOR_GREEN :: imgui.Vec4{0.2, 0.6, 0.2, 1.0}
COLOR_GREEN_HOVERED :: imgui.Vec4{0.3, 0.7, 0.3, 1.0}
COLOR_GREEN_ACTIVE :: imgui.Vec4{0.1, 0.5, 0.1, 1.0}

COLOR_U32 :: imgui.GetColorU32ImVec4

show_gui :: proc(window_width: u32, window_height: u32, window: glfw.WindowHandle) {
	ctx := (^utils.SharedContext)(glfw.GetWindowUserPointer(window))

	imgui.SetNextWindowPos(imgui.Vec2{0, 0}, imgui.Cond.Always)
	imgui.SetNextWindowSize(
		imgui.Vec2{f32(window_width / 6), f32(window_height)},
		imgui.Cond.Always,
	)

	imgui.PushStyleColor(
		imgui.Col.WindowBg,
		imgui.GetColorU32ImVec4(
			imgui.Vec4{0.05, 0.05, 0.05, 1.0} if ctx.game_focused else imgui.Vec4{0.1, 0.1, 0.1, 1.0},
		),
	)

	if imgui.Begin("Main Window", nil, {.NoMove, .NoResize, .NoCollapse}) {
		imgui.Checkbox("Game focused?", &ctx.game_focused)

		if (imgui.CollapsingHeader("Texture Atlases")) {
			for name, atlas_ptr in ctx.atlases {
				imgui.SeparatorText(strings.unsafe_string_to_cstring(name))

				imgui.InputText(
					strings.clone_to_cstring(fmt.aprintf("Source##%s", name)),
					atlas_ptr.header.filename,
					128,
				)

				if imgui.Button("Save") {
					ctx.event_handlers["save_atlas"](ctx)
				}
			}

			imgui.SeparatorText("Load Texture Atlas")

			// FIX: These cstrings are recreated every frame, causing the input text to reset.
			filepath: cstring = strings.clone_to_cstring("")
			name: cstring = strings.clone_to_cstring("")

			imgui.InputText(strings.clone_to_cstring("Source##atlas_path"), filepath, 256)
			imgui.InputText(strings.clone_to_cstring("Name##atlas_name"), name, 64)

			if imgui.Button("Load Atlas", {imgui.GetContentRegionAvail()[0], 0}) {
				ctx.event_handlers["load_atlas"](ctx, string(filepath), string(name))
			}
		}

		if (imgui.CollapsingHeader("Add Object##add_object_header")) {
			imgui.SeparatorText("General##generalsep_addobject")
			imgui.InputText(
				strings.clone_to_cstring("Name##object_name"),
				ctx.add_object.name,
				256,
			)

			imgui.InputText(
				strings.clone_to_cstring("Source##object_path"),
				ctx.add_object.texture_source,
				256,
			)

			imgui.InputFloat2(
				strings.clone_to_cstring("Position##object_position"),
				&ctx.add_object.position,
			)

			imgui.SeparatorText("Layer##layersep_addobject")
			for &layer, i in ctx.render_context.layers {
				if imgui.Selectable(
					strings.clone_to_cstring(
						fmt.aprintf("%s##%s_addobject", layer.name, layer.name),
					),
					ctx.add_object.layer == i32(i),
				) {
					ctx.add_object.layer = i32(i)
				}
			}

			imgui.Spacing()

			imgui.PushStyleColor(imgui.Col.Button, COLOR_U32(COLOR_GREEN))
			imgui.PushStyleColor(imgui.Col.ButtonHovered, COLOR_U32(COLOR_GREEN_HOVERED))
			imgui.PushStyleColor(imgui.Col.ButtonActive, COLOR_U32(COLOR_GREEN_ACTIVE))
			if imgui.Button(
				"Add Object##add_object_button",
				{imgui.GetContentRegionAvail()[0], 0},
			) {
				ok := ctx.event_handlers["add_object"](ctx)
				fmt.println("Add Object returned: ", ok)
				if ok != nil {
					ctx.error_message = fmt.aprintf("Failed to add object: %s", ok)
					fmt.println("Error message set to: ", ctx.error_message)
					imgui.OpenPopup("Error")
				}
			}
			imgui.PopStyleColor(3)
		}

		if (imgui.CollapsingHeader("Render Layers")) {
			for &layer, i in ctx.render_context.layers {
				if imgui.InputInt(
					strings.clone_to_cstring(fmt.aprintf("%s##%s_layers", layer.name, layer.name)),
					&layer.z_layer,
				) {
					// sort the layers based on their z_layer
					sort.quick_sort_proc(
						ctx.render_context.layers[:],
						proc(a: rendering.RenderLayer, b: rendering.RenderLayer) -> int {
							return sort.compare_i32s(a.z_layer, b.z_layer)
						},
					)
				}
			}
		}
	}

	if imgui.BeginPopupModal("Error", nil, {.AlwaysAutoResize}) {
		imgui.TextWrapped(strings.clone_to_cstring(ctx.error_message))
		imgui.Separator()

		label: cstring = "OK"

		size: f32 = f32(ctx.window_size[0]) / 12.0
		available := imgui.GetContentRegionAvail().x

		offset := (available - size) / 2
		imgui.SetCursorPosX(imgui.GetCursorPosX() + offset)

		imgui.PushStyleColor(imgui.Col.Button, COLOR_U32(COLOR_GREEN))
		imgui.PushStyleColor(imgui.Col.ButtonHovered, COLOR_U32(COLOR_GREEN_HOVERED))
		imgui.PushStyleColor(imgui.Col.ButtonActive, COLOR_U32(COLOR_GREEN_ACTIVE))
		if imgui.Button(label, imgui.Vec2{size, 0}) {
			ctx.error_message = ""
			imgui.CloseCurrentPopup()
		}
		imgui.PopStyleColor(3)
		imgui.EndPopup()
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
