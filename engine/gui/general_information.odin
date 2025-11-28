package gui

import "core:fmt"
import "core:slice"
import "core:sort"
import "core:strings"

import "vendor:glfw"

import atl "../../engine/atlas"
import rendering "../../engine/rendering"
import imgui "../../third_party/imgui"
import "../../utils"
import "../../utils/globals"
import rm "../resource_manager"
import scripts "../scripts"

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

		if imgui.Checkbox("Game focused?", &ctx.game_focused) {
			if ctx.game_focused {
				// run start callbacks
				for reg_script in ctx.script_manager.registered_scripts {
					script := (^scripts.Script)(reg_script.script)
					if script.start_callback != nil {
						script.start_callback(ctx, reg_script.target, nil)
					}
				}
			}
		}
		// if imgui.Checkbox("Editing preset?", &ctx.editing_preset) {
		// 	for &layer in (^rendering.RendererContext)(ctx.render_context).layers {
		// 		for &obj in layer.objects {
		// 			obj.sprite.hovered = ctx.editing_preset
		// 		}
		// 	}
		// }

		imgui.InputFloat2("Camera Position", &ctx.camera.position)

		if (imgui.CollapsingHeader("Texture Atlases")) {
			findable_combo_input(
				"atlas_listbox",
				"Loaded Atlases",
				ctx.manager.atlas_manager.keys[:],
				&ctx.add_preset.atlas_name,
			)

			if i32(len(ctx.manager.atlas_manager.keys)) > ctx.add_preset.atlas_name {
				atlas_name := ctx.manager.atlas_manager.keys[i32(ctx.add_preset.atlas_name)]
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
						ctx.open_popups["error"] = true
					}
				}
			}

			imgui.SeparatorText("Load Texture Atlas")

			imgui.InputText(
				strings.clone_to_cstring("Source##atlas_path"),
				ctx.add_atlas.filepath,
				256,
			)

			if green_button("Load Atlas", {imgui.GetContentRegionAvail()[0], 0}) {
				err := ctx.event_handlers["load_atlas"](ctx)
				if err != nil {
					ctx.error_message = fmt.aprintf("Failed to load atlas: %s", err)
					ctx.open_popups["error"] = true
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
					ctx.open_popups["error"] = true
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
			@(static) selected_texture_index: i32 = 0

			findable_combo_input(
				"loaded_textures_listbox",
				"Loaded Textures",
				ctx.manager.texture_manager.keys[:],
				&selected_texture_index,
			)

			if len(ctx.manager.texture_manager.keys) > 0 {
				selected_texture := utils.texture_at_index(
					&ctx.manager.texture_manager,
					globals.TextureType(selected_texture_index),
				)

				width := imgui.GetContentRegionAvail()[0]

				imgui.PushID("SelectedTextureImage")
				imgui.Image(
					u64(selected_texture.id),
					imgui.Vec2 {
						width,
						width * f32(selected_texture.height) / f32(selected_texture.width),
					},
				)

				if imgui.BeginDragDropSource({.SourceAllowNullID}) {
					payload := DraggedTexturePayload {
						texture_index = selected_texture_index,
						source        = DraggedTextureSource.FromTextureBrowser,
					}

					imgui.SetDragDropPayload("ITEM", &payload, size_of(DraggedTexturePayload))

					imgui.EndDragDropSource()
				}
				imgui.PopID()
			}

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
					ctx.open_popups["error"] = true
				} else {
					ctx.add_texture.name = utils.empty_cstring(64)
					ctx.add_texture.source = utils.empty_cstring(256)
				}
			}
		}
	}

	if ctx.open_popups["load_texture"] or_else false {
		load_texture_popup(ctx)
	}

	if ctx.open_popups["error"] or_else false {
		imgui.Begin("Error")
		imgui.TextWrapped(strings.clone_to_cstring(ctx.error_message))
		imgui.Separator()

		size: f32 = f32(ctx.window_size[0]) / 12.0
		available := imgui.GetContentRegionAvail().x

		offset := (available - size) / 2
		imgui.SetCursorPosX(imgui.GetCursorPosX() + offset)

		if green_button("OK", imgui.Vec2{size, 0}) {
			ctx.error_message = ""
			ctx.open_popups["error"] = false
		}
		imgui.End()
	}

	imgui.End()

}
