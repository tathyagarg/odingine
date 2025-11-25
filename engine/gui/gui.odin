package gui

import "core:fmt"
import "core:slice"
import "core:sort"
import "core:strings"

import "vendor:glfw"

import rendering "../../engine/rendering"
import imgui "../../third_party/imgui"
import "../../utils"
import "../../utils/globals"
import rm "../resource_manager"
import "../scripts"

COLOR_GREEN :: imgui.Vec4{0.2, 0.6, 0.2, 1.0}
COLOR_GREEN_HOVERED :: imgui.Vec4{0.3, 0.7, 0.3, 1.0}
COLOR_GREEN_ACTIVE :: imgui.Vec4{0.1, 0.5, 0.1, 1.0}

COLOR_RED :: imgui.Vec4{0.6, 0.2, 0.2, 1.0}
COLOR_RED_HOVERED :: imgui.Vec4{0.7, 0.3, 0.3, 1.0}
COLOR_RED_ACTIVE :: imgui.Vec4{0.5, 0.1, 0.1, 1.0}

COLOR_U32 :: imgui.GetColorU32ImVec4

green_button :: proc(label: cstring, size: imgui.Vec2 = imgui.Vec2{0, 0}) -> bool {
	imgui.PushStyleColor(imgui.Col.Button, COLOR_U32(COLOR_GREEN))
	imgui.PushStyleColor(imgui.Col.ButtonHovered, COLOR_U32(COLOR_GREEN_HOVERED))
	imgui.PushStyleColor(imgui.Col.ButtonActive, COLOR_U32(COLOR_GREEN_ACTIVE))
	result := imgui.Button(label, size)
	imgui.PopStyleColor(3)
	return result
}

findable_combo_input :: proc(
	combo_id: cstring,
	label: cstring,
	options: []string,
	selected_index: ^i32,
) {
	imgui.PushID(combo_id)

	name :=
		strings.clone_to_cstring(options[(^i32)(selected_index)^]) if len(options) > 0 else strings.clone_to_cstring("")

	if imgui.BeginCombo(label, name) {
		@(static) filter: imgui.TextFilter
		if imgui.IsWindowAppearing() {
			imgui.SetKeyboardFocusHere()
			imgui.TextFilter_Clear(&filter)
		}

		imgui.TextFilter_Draw(&filter, "##Filter", -1)

		for i in 0 ..< len(options) {
			if imgui.TextFilter_PassFilter(&filter, strings.clone_to_cstring(options[i])) {
				imgui.PushID(strings.clone_to_cstring(fmt.aprintf("%s_%s", combo_id, options[i])))
				if imgui.Selectable(
					strings.clone_to_cstring(options[i]),
					selected_index^ == i32(i),
				) {
					selected_index^ = i32(i)
				}
				imgui.PopID()
			}
		}
		imgui.EndCombo()
	}

	imgui.PopID()
}

texture_input :: proc(
	combo_id: cstring,
	label: cstring,
	options: []string,
	ptr: ^scripts.TextureType,
	texture_manager: ^rm.TextureManager,
) {
	imgui.Image(
		u64(utils.texture_at_index(texture_manager, (^globals.TextureType)(ptr)^).id),
		imgui.Vec2{16, 16},
	)

	imgui.SameLine()

	findable_combo_input(combo_id, label, options, (^i32)(ptr))
}

show_gui :: proc(window_width: u32, window_height: u32, window: glfw.WindowHandle) {
	ctx := (^utils.SharedContext)(glfw.GetWindowUserPointer(window))

	imgui.PushStyleColor(
		imgui.Col.WindowBg,
		imgui.GetColorU32ImVec4(
			imgui.Vec4{0.05, 0.05, 0.05, 1.0} if ctx.game_focused else imgui.Vec4{0.1, 0.1, 0.1, 1.0},
		),
	)

	general_information_window(window_width, window_height, window)
	mysterious_bottom_window(window_width, window_height, window)
	object_details_window(window_width, window_height, window)

	imgui.PopStyleColor(1)
}

general_information_window :: proc(
	window_width: u32,
	window_height: u32,
	window: glfw.WindowHandle,
) {
	ctx := (^utils.SharedContext)(glfw.GetWindowUserPointer(window))

	imgui.SetNextWindowPos(imgui.Vec2{0, 0}, imgui.Cond.Always)
	imgui.SetNextWindowSize(
		imgui.Vec2{f32(window_width / 6), f32(window_height)},
		imgui.Cond.Always,
	)

	if imgui.Begin("Main Window", nil, {.NoMove, .NoResize, .NoCollapse, .MenuBar, .NoTitleBar}) {
		if (imgui.BeginMenuBar()) {
			if (imgui.BeginMenu("Texture")) {
				if (imgui.MenuItem("Load Texture")) {
					fmt.println("Opening Load Texture Popup")
					ctx.open_popups["load_texture"] = true
				}
				imgui.EndMenu()
			}
			imgui.EndMenuBar()
		}

		imgui.Checkbox("Game focused?", &ctx.game_focused)

		if (imgui.CollapsingHeader("Texture Atlases")) {
			findable_combo_input(
				"atlas_listbox",
				"Loaded Atlases",
				ctx.manager.atlas_manager.keys[:],
				&ctx.add_preset.atlas_name,
			)

			if i32(len(ctx.manager.atlas_manager.keys)) > ctx.add_preset.atlas_name {
				atlas_name := ctx.manager.atlas_manager.keys[i32(ctx.selected_atlas)]
				atlas := ctx.manager.atlas_manager.atlases[atlas_name]

				imgui.InputText(
					strings.clone_to_cstring(fmt.aprintf("Source##%s", atlas_name)),
					atlas.header.filename,
					128,
				)

				imgui.PushID(
					strings.clone_to_cstring(fmt.aprintf("SaveAtlasButton%s", atlas_name)),
				)
				if green_button("Save", {imgui.GetContentRegionAvail()[0], 0}) {
					ctx.event_handlers["save_atlas"](ctx)
				}
				imgui.PopID()

				presets := []string{}
				if i32(len(ctx.manager.atlas_manager.keys)) > ctx.add_preset.atlas_name {
					presets = ctx.manager.atlas_manager.atlases[ctx.manager.atlas_manager.keys[i32(ctx.add_preset.atlas_name)]].presets.keys[:]
				}

				imgui.SeparatorText("Presets")

				findable_combo_input(
					"preset_combo",
					"Preset##preset_combo",
					presets,
					&ctx.add_preset.preset_name,
				)

				findable_combo_input(
					"layer_combo",
					"Layer##layer_combo",
					slice.mapper(
						(^rendering.RendererContext)(ctx.render_context).layers[:],
						proc(layer: rendering.RenderLayer) -> string {
							return string(layer.name)
						},
					),
					&ctx.add_preset.layer_index,
				)

				imgui.InputFloat2("Offset", &ctx.add_preset.offset)

				if green_button("Load Preset", {imgui.GetContentRegionAvail()[0], 0}) {
					err := ctx.event_handlers["render_atlas_preset"](ctx)
					if err != nil {
						ctx.error_message = fmt.aprintf("Failed to load atlas preset: %s", err)
						imgui.OpenPopup("Error")
					}
				}
			}

			imgui.SeparatorText("Load Texture Atlas")

			imgui.InputText(strings.clone_to_cstring("Name##atlas_name"), ctx.add_atlas.name, 64)
			imgui.InputText(
				strings.clone_to_cstring("Source##atlas_path"),
				ctx.add_atlas.filepath,
				256,
			)

			if green_button("Load Atlas", {imgui.GetContentRegionAvail()[0], 0}) {
				err := ctx.event_handlers["load_atlas"](ctx)
				if err != nil {
					ctx.error_message = fmt.aprintf("Failed to load atlas: %s", err)
					imgui.OpenPopup("Error")
				}
			}
		}

		if (imgui.CollapsingHeader("Add Object##add_object_header")) {
			imgui.SeparatorText("General##generalsep_addobject")
			imgui.InputText(
				strings.clone_to_cstring("Name##object_name"),
				ctx.add_object.name,
				256,
			)

			texture_input(
				strings.clone_to_cstring("object_texture_input"),
				strings.clone_to_cstring("Texture##object_texture"),
				ctx.manager.texture_manager.keys[:],
				&ctx.add_object.texture,
				&ctx.manager.texture_manager,
			)

			imgui.InputFloat2(
				strings.clone_to_cstring("Position##object_position"),
				&ctx.add_object.position,
			)

			imgui.SeparatorText("Layer##layersep_addobject")
			for &layer, i in (^rendering.RendererContext)(ctx.render_context).layers {
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

			if green_button(
				"Add Object##add_object_button",
				{imgui.GetContentRegionAvail()[0], 0},
			) {
				err := ctx.event_handlers["add_object"](ctx)
				if err != nil {
					ctx.error_message = fmt.aprintf("Failed to add object: %s", err)
					imgui.OpenPopup("Error")
				}
			}

			imgui.Spacing()
		}

		if (imgui.CollapsingHeader("Render Layers")) {
			for &layer, i in (^rendering.RendererContext)(ctx.render_context).layers {
				if imgui.InputInt(
					strings.clone_to_cstring(fmt.aprintf("%s##%s_layers", layer.name, layer.name)),
					&layer.z_layer,
				) {
					// sort the layers based on their z_layer
					sort.quick_sort_proc(
						(^rendering.RendererContext)(ctx.render_context).layers[:],
						proc(a: rendering.RenderLayer, b: rendering.RenderLayer) -> int {
							return sort.compare_i32s(a.z_layer, b.z_layer)
						},
					)
				}
			}
		}

		if (imgui.CollapsingHeader("Textures")) {
			names: [^]cstring
			raw_names := [dynamic]cstring{}

			for name in ctx.manager.texture_manager.keys {
				append(&raw_names, strings.clone_to_cstring(name))
			}

			names = raw_data(raw_names[:])

			selected: i32 = 0

			imgui.ListBox(
				strings.clone_to_cstring("Loaded Textures##loaded_textures_listbox"),
				&selected,
				names[:],
				i32(len(ctx.manager.texture_manager.keys)),
				8,
			)

			imgui.SeparatorText("Load Texture")
			imgui.InputText(
				strings.clone_to_cstring("Name##texture_name"),
				ctx.add_texture.name,
				64,
			)

			imgui.InputText(
				strings.clone_to_cstring("Source##texture_path"),
				ctx.add_texture.source,
				256,
			)

			if imgui.Button("Load Texture", {imgui.GetContentRegionAvail()[0], 0}) {
				err := ctx.event_handlers["load_texture"](ctx)
				if err != nil {
					ctx.error_message = fmt.aprintf("Failed to load texture: %s", err)
					imgui.OpenPopup("Error")
				} else {
					ctx.add_texture.name = utils.empty_cstring(64)
					ctx.add_texture.source = utils.empty_cstring(256)
				}
			}
		}
	}

	if ctx.open_popups["load_texture"] or_else false {
		imgui.SetNextWindowPos(imgui.GetMainViewport().Pos)
		imgui.SetNextWindowSize(imgui.GetMainViewport().Size)

		pos := imgui.GetMainViewport().Pos
		size := imgui.GetMainViewport().Size

		// imgui.SetNextWindowSize(imgui.Vec2{size.x / 2, size.y / 2})
		imgui.SetNextWindowSizeConstraints(imgui.Vec2{0, 0}, imgui.Vec2{size.x / 3, 200})
		imgui.SetNextWindowPos(
			imgui.Vec2{pos.x + size.x / 3, pos.y + size.y / 3},
			imgui.Cond.Appearing,
		)

		if imgui.Begin(
			"Load Texture Modal",
			&ctx.open_popups["load_texture"],
			{.NoResize, .NoCollapse, .AlwaysAutoResize},
		) {
			if ctx.manager.preview_texture != nil {
				preview_texture := (^rm.Texture)(ctx.manager.preview_texture)
				texture_size_x := 128
				texture_size_y := 128 * preview_texture.height / preview_texture.width

				imgui.Image(
					u64(preview_texture.id),
					imgui.Vec2{f32(texture_size_x), f32(texture_size_y)},
				)
			} else {
				imgui.Text("No preview available")
			}

			imgui.SameLine()

			imgui.BeginGroup()

			imgui.Text("Texture Details")

			imgui.InputText("Name", ctx.add_texture.name, 64)
			imgui.InputText("Source", ctx.add_texture.source, 256)

			imgui.Separator()

			if imgui.Button("Preview", imgui.Vec2{imgui.GetContentRegionAvail().x / 3 - 5, 0}) {
				err := ctx.event_handlers["load_texture_preview"](ctx)
				if err != nil {
					ctx.error_message = fmt.aprintf("Failed to preview texture: %s", err)
				}
			}

			imgui.SameLine()

			if green_button("Load", imgui.Vec2{imgui.GetContentRegionAvail().x / 2 - 5, 0}) {
				ctx.event_handlers["make_texture_permanent_if_preview"](ctx)
				err := ctx.event_handlers["load_texture"](ctx)
				if err != nil {
					ctx.error_message = fmt.aprintf("Failed to load texture: %s", err)
				} else {
					ctx.add_texture.name = utils.empty_cstring(64)
					ctx.add_texture.source = utils.empty_cstring(256)
				}
			}

			imgui.SameLine()

			imgui.PushStyleColor(imgui.Col.Button, COLOR_U32(COLOR_RED))
			imgui.PushStyleColor(imgui.Col.ButtonHovered, COLOR_U32(COLOR_RED_HOVERED))
			imgui.PushStyleColor(imgui.Col.ButtonActive, COLOR_U32(COLOR_RED_ACTIVE))

			if imgui.Button("Cancel", imgui.Vec2{imgui.GetContentRegionAvail().x, 0}) {
				ctx.open_popups["load_texture"] = false

				ctx.add_texture.name = utils.empty_cstring(64)
				ctx.add_texture.source = utils.empty_cstring(256)
			}

			imgui.PopStyleColor(3)

			imgui.EndGroup()

			imgui.End()
		}
	}

	if imgui.BeginPopupModal("Error", nil, {.AlwaysAutoResize}) {
		imgui.TextWrapped(strings.clone_to_cstring(ctx.error_message))
		imgui.Separator()

		size: f32 = f32(ctx.window_size[0]) / 12.0
		available := imgui.GetContentRegionAvail().x

		offset := (available - size) / 2
		imgui.SetCursorPosX(imgui.GetCursorPosX() + offset)

		if green_button("OK", imgui.Vec2{size, 0}) {
			ctx.error_message = ""
			imgui.CloseCurrentPopup()
		}
		imgui.EndPopup()
	}

	imgui.End()

}

object_details_window :: proc(window_width: u32, window_height: u32, window: glfw.WindowHandle) {
	ctx := (^utils.SharedContext)(glfw.GetWindowUserPointer(window))

	imgui.SetNextWindowPos(imgui.Vec2{f32(5 * window_width / 6), 0}, imgui.Cond.Always)
	imgui.SetNextWindowSize(
		imgui.Vec2{f32(window_width / 6), f32(window_height)},
		imgui.Cond.Always,
	)
	if imgui.Begin("Object Details", nil, {.NoMove, .NoResize, .NoCollapse}) {
		if ctx.focused_object != nil {
			focused := (^rendering.RenderObject)(ctx.focused_object)

			texture_size_x := 64
			texture_size_y := 64 * focused.texture.height / focused.texture.width

			imgui.Image(
				u64(focused.texture.id),
				imgui.Vec2{f32(texture_size_x), f32(texture_size_y)},
			)

			imgui.SameLine()

			imgui.BeginGroup()

			imgui.Text(strings.clone_to_cstring(fmt.aprintf("Name: %s", focused.name)))
			imgui.Text(strings.clone_to_cstring(fmt.aprintf("Texture: %s", focused.texture.name)))

			imgui.EndGroup()

			imgui.InputFloat2(
				strings.clone_to_cstring("Position##object_position_input"),
				&focused.position,
			)

			imgui.InputFloat2(strings.clone_to_cstring("Size##object_size_input"), &focused.size)

			imgui.InputFloat(
				strings.clone_to_cstring("Rotation##object_rotation_input"),
				&focused.rotation,
			)

			imgui.Spacing()

			imgui.PushStyleColor(imgui.Col.Button, COLOR_U32(COLOR_RED))
			imgui.PushStyleColor(imgui.Col.ButtonHovered, COLOR_U32(COLOR_RED_HOVERED))
			imgui.PushStyleColor(imgui.Col.ButtonActive, COLOR_U32(COLOR_RED_ACTIVE))
			if imgui.Button(
				"Delete Object##delete_object_button",
				{imgui.GetContentRegionAvail()[0], 0},
			) {
				fmt.println("Delete Object button pressed")
				err := ctx.event_handlers["delete_object"](ctx)
				if err != nil {
					ctx.error_message = fmt.aprintf("Failed to delete object: %s", err)
					imgui.OpenPopup("Error")
				} else {
					ctx.focused_object = nil
				}
			}
			imgui.PopStyleColor(3)

			imgui.SeparatorText("Scripts")
			imgui.BeginGroup()
			imgui.Text("Attached Scripts:")
			for script_handle, i in focused.scripts {
				script := (^scripts.Script)(script_handle)

				if imgui.Button(
					strings.clone_to_cstring(
						fmt.aprintf("%s##remove_script_%s", script.name, script.name),
					),
				) {
					ordered_remove(&focused.scripts, i)
				}
			}
			imgui.EndGroup()

			imgui.SameLine()

			imgui.BeginGroup()
			imgui.Text("Available Scripts:")
			show_scripts: for script_handle, i in ctx.script_manager.scripts {
				script := (^scripts.Script)(ctx.script_manager.scripts[i])

				for j in 0 ..< len(focused.scripts) {
					existing_script := focused.scripts[j]
					if (^scripts.Script)(existing_script).name == script.name {
						continue show_scripts
					}
				}

				text := fmt.aprintf("%s##add_script_%s", script.name, script.name)

				if imgui.Button(strings.clone_to_cstring(text)) {
					script_clone := scripts.clone_script(script)

					append(&focused.scripts, globals.ScriptHandle(script_clone))
					fmt.println("Adding script:", script.name)
					for key, _ in script_clone.key_listeners {
						if ctx.script_manager.registered_scripts[key] == nil {
							ctx.script_manager.registered_scripts[key] =
								[dynamic]utils.RegisteredScript{}
						}

						switch script_clone.argument_type {
						case typeid_of(scripts.TopDownMovementScriptInput):
							args := (^scripts.TopDownMovementScriptInput)(script_clone.arguments)
							this_texture := focused.texture.name

							for texture_name, texture_id in ctx.manager.texture_manager.keys {
								if texture_name == this_texture {
									args.front_texture = (scripts.TextureType)(texture_id)
									args.left_texture = (scripts.TextureType)(texture_id)
									args.right_texture = (scripts.TextureType)(texture_id)
									args.back_texture = (scripts.TextureType)(texture_id)
									break
								}
							}
						}

						append(
							&ctx.script_manager.registered_scripts[key],
							utils.RegisteredScript {
								script = globals.ScriptHandle(script_clone),
								target = ctx.focused_object,
							},
						)
						fmt.println("Registered script for key:", key)
					}
				}
				imgui.SetItemTooltip(
					strings.clone_to_cstring(
						fmt.aprintf(
							"%s\n%s\n%s",
							script.name,
							strings.repeat("-", len(script.name)),
							script.description,
						),
					),
				)

			}
			imgui.EndGroup()

			for script_handle, i in focused.scripts {
				script := (^scripts.Script)(script_handle)
				imgui.SeparatorText(
					strings.clone_to_cstring(fmt.aprintf("Script: %s", script.name)),
				)

				for arg_desc in script.argument_descriptors {
					switch arg_desc.type_info {
					case typeid_of(f32):
						ptr := rawptr(uintptr(script.arguments) + arg_desc.offset)
						imgui.InputFloat(
							strings.clone_to_cstring(
								fmt.aprintf(
									"%s##%s_%s",
									arg_desc.name,
									script.name,
									arg_desc.name,
								),
							),
							(^f32)(ptr),
						)
					case typeid_of(cstring):
						ptr := rawptr(uintptr(script.arguments) + arg_desc.offset)
						imgui.InputText(
							strings.clone_to_cstring(
								fmt.aprintf(
									"%s##%s_%s",
									arg_desc.name,
									script.name,
									arg_desc.name,
								),
							),
							(^cstring)(ptr)^,
							256,
						)
					case typeid_of(scripts.TextureType):
						ptr := rawptr(uintptr(script.arguments) + arg_desc.offset)

						keys := ctx.manager.texture_manager.keys
						names := strings.join(keys[:], "\x00")

						texture_input(
							strings.clone_to_cstring(
								fmt.aprintf("%s_%s", script.name, arg_desc.name),
							),
							strings.clone_to_cstring(
								fmt.aprintf(
									"%s##%s_%s",
									arg_desc.name,
									script.name,
									arg_desc.name,
								),
							),
							keys[:],
							(^scripts.TextureType)(ptr),
							&ctx.manager.texture_manager,
						)

					}
				}
			}
		} else {
			imgui.Text("No object selected.")
		}
	}

	imgui.End()
}

mysterious_bottom_window :: proc(
	window_width: u32,
	window_height: u32,
	window: glfw.WindowHandle,
) {
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
