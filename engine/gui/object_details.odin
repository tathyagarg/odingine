package gui

import "core:fmt"
import "core:slice"
import "core:strings"

import "vendor:glfw"

import rendering "../../engine/rendering"
import imgui "../../third_party/imgui"
import "../../utils"
import "../../utils/globals"
import rm "../resource_manager"
import scripts "../scripts"

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
			if (focused.kind != .None) {
				imgui.Text(
					strings.clone_to_cstring(
						fmt.aprintf(
							"Kind: %s",
							rendering.render_object_kind_to_string(focused.kind),
						),
					),
				)
			}

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

			@(static) selected_index: i32 = 0

			findable_combo_input(
				"layer_combo",
				"Layer##layer_combo",
				slice.mapper(
					(^rendering.RendererContext)(ctx.render_context).layers[:],
					proc(layer: rendering.RenderLayer) -> string {
						return string(layer.name)
					},
				),
				&selected_index,
				ctx,
				proc(selected_index: ^i32, ctx: ^utils.SharedContext) {
					focused := (^rendering.RenderObject)(ctx.focused_object)

					for &layer in (^rendering.RendererContext)(ctx.render_context).layers[:] {
						for obj, i in layer.objects {
							if obj.name == focused.name {
								ordered_remove(&layer.objects, i)
								target_layer := &(^rendering.RendererContext)(ctx.render_context).layers[selected_index^]
								append(&target_layer.objects, focused^)
								fmt.println(
									"Layers now: ",
									(^rendering.RendererContext)(ctx.render_context).layers,
								)
								return
							}
						}
					}
				},
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
					ctx.open_popups["error"] = true
				} else {
					ctx.focused_object = nil
				}
			}
			imgui.PopStyleColor(3)

			// not doing anything for .None so partial switch
			#partial switch focused.kind {
			case .AtlasPreset:
				imgui.SeparatorText("Atlas Preset Info")
				if (imgui.Button(
						   "Edit Preset##edit_preset_button",
						   {imgui.GetContentRegionAvail()[0], 0},
					   )) {
					if ctx.editing_preset != globals.RenderObjectHandle(ctx.focused_object) {
						ctx.editing_preset = globals.RenderObjectHandle(ctx.focused_object)
					} else {
						ctx.editing_preset = nil
					}
				}
			}

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
						&ctx.script_manager.registered_scripts,
						utils.RegisteredScript {
							script = globals.ScriptHandle(script_clone),
							target = ctx.focused_object,
						},
					)
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
				if (imgui.TreeNode(script.name)) {
					for arg_desc in script.argument_descriptors {
						ptr := rawptr(uintptr(script.arguments) + arg_desc.offset)
						switch arg_desc.type_info {
						case typeid_of(f32):
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
						case typeid_of(bool):
							imgui.Checkbox(
								strings.clone_to_cstring(
									fmt.aprintf(
										"%s##%s_%s",
										arg_desc.name,
										script.name,
										arg_desc.name,
									),
								),
								(^bool)(ptr),
							)
						case typeid_of(scripts.TextureType):
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
						if arg_desc.tooltip != "" {
							tooltip(arg_desc.name, arg_desc.tooltip)
						}
					}
					imgui.TreePop()
				}
			}
		} else {
			imgui.Text("No object selected.")
		}
	}

	imgui.End()
}
