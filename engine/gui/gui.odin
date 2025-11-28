package gui

import "core:fmt"
import "core:math"
import "core:slice"
import "core:strings"

import "vendor:glfw"

import atl "../../engine/atlas"
import rendering "../../engine/rendering"
import imgui "../../third_party/imgui"
import "../../utils"
import "../../utils/globals"
import sprite "../rendering/sprite"
import rm "../resource_manager"

COLOR_GREEN :: imgui.Vec4{0.2, 0.6, 0.2, 1.0}
COLOR_GREEN_HOVERED :: imgui.Vec4{0.3, 0.7, 0.3, 1.0}
COLOR_GREEN_ACTIVE :: imgui.Vec4{0.1, 0.5, 0.1, 1.0}

COLOR_RED :: imgui.Vec4{0.6, 0.2, 0.2, 1.0}
COLOR_RED_HOVERED :: imgui.Vec4{0.7, 0.3, 0.3, 1.0}
COLOR_RED_ACTIVE :: imgui.Vec4{0.5, 0.1, 0.1, 1.0}

COLOR_U32 :: imgui.GetColorU32ImVec4


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

	if imgui.IsMouseReleased(imgui.MouseButton.Left) {
		mouse_pos := imgui.GetMousePos()
		scissor := rendering.get_scissor_bounds(
			.Development,
			i32(ctx.window_size[0]),
			i32(ctx.window_size[1]),
		)

		x_off, y_off, width, height := scissor[0], scissor[1], scissor[2], scissor[3]

		x := (2 * mouse_pos.x - f32(x_off)) / 2 / globals.WINDOW_TO_SCREEN_SCALE
		y := mouse_pos.y / globals.WINDOW_TO_SCREEN_SCALE

		fmt.println("Mouse released at ", mouse_pos, " transformed to ", x, ", ", y)

		if !(x < 0 ||
			   x > f32(width) / 2 / globals.WINDOW_TO_SCREEN_SCALE ||
			   y < 0 ||
			   y > f32(height) * globals.WINDOW_TO_SCREEN_SCALE) {

			if !imgui.IsDragDropPayloadBeingAccepted() {
				if payload := imgui.GetDragDropPayload(); payload != nil {
					fmt.println("payload ", payload)

					payload_data := (^DraggedTexturePayload)(payload.Data)
					fmt.println("payload_data ", payload_data)

					switch payload_data.source {
					case .FromTextureBrowser:
						selected_texture_index := payload_data.texture_index

						fmt.println("selected_texture_index ", selected_texture_index)

						selected_texture := utils.texture_at_index(
							&ctx.manager.texture_manager,
							globals.TextureType(selected_texture_index),
						)

						ctx.add_object.name = strings.clone_to_cstring(selected_texture.name)
						ctx.add_object.texture = globals.TextureType(selected_texture_index)
						ctx.add_object.position = [2]f32 {
							f32(x) + ctx.camera.position[0],
							f32(y) + ctx.camera.position[1],
						}
						ctx.add_object.layer = 0

						fmt.println("Add object:", ctx.add_object)

						ctx.event_handlers["add_object"](ctx)
					case .FromTilemapEditor:
						if ctx.editing_preset != nil {
							preset_object := (^rendering.RenderObject)(ctx.editing_preset)
							atlas := (^atl.Atlas)(preset_object.data)
							preset_data: atl.Preset = atlas.presets.presets[preset_object.name]

							relative_tile_position := [2]int {
								int(
									math.floor(
										(f32(x) -
											preset_object.position[0] +
											ctx.camera.position[0]) /
										(f32(atlas.header.sprite_size[0]) * globals.TILE_SCALE),
									),
								),
								int(
									math.floor(
										(f32(y) -
											preset_object.position[1] +
											ctx.camera.position[1]) /
										(f32(atlas.header.sprite_size[1]) * globals.TILE_SCALE),
									),
								),
							}

							new_preset := preset_data
							if (relative_tile_position[0] > preset_data.size[0] - 1) ||
							   (relative_tile_position[1] > preset_data.size[1] - 1) {
								new_width := math.max(
									preset_data.size[0],
									relative_tile_position[0] + 1,
								)

								new_height := math.max(
									preset_data.size[1],
									relative_tile_position[1] + 1,
								)

								new_preset = atl.Preset {
									size     = [2]int{new_width, new_height},
									tile_ids = make([]int, new_width * new_height),
								}

								for i: int = 0; i < new_width * new_height; i += 1 {
									new_preset.tile_ids[i] = -1
								}

								fmt.println(
									"Old size: ",
									preset_data.size,
									" New size: ",
									new_preset.size,
								)

								preset_object.size = {
									f32(atlas.header.sprite_size[0]) *
									globals.TILE_SCALE *
									f32(new_preset.size[0]),
									f32(atlas.header.sprite_size[1]) *
									globals.TILE_SCALE *
									f32(new_preset.size[1]),
								}
							}

							for y: int = 0; y < preset_data.size[1]; y += 1 {
								for x: int = 0; x < preset_data.size[0]; x += 1 {
									old_index := x + y * preset_data.size[0]
									new_index := x + y * new_preset.size[0]
									new_preset.tile_ids[new_index] =
										preset_data.tile_ids[old_index]
								}
							}

							fmt.println("Relative tile position: ", relative_tile_position)
							fmt.println(
								"Setting tile at index ",
								relative_tile_position[0] +
								relative_tile_position[1] * new_preset.size[0],
								" to texture index ",
								payload_data.texture_index,
							)
							fmt.println("New preset size: ", new_preset.size)
							new_preset.tile_ids[relative_tile_position[0] + relative_tile_position[1] * new_preset.size[0]] =
								int(payload_data.texture_index)

							atlas.presets.presets[preset_object.name] = new_preset
							ctx.event_handlers["save_atlas"](ctx)
							preset_object.sprite = sprite.initialize_preset(
								ctx.manager,
								&preset_object.sprite.shader,
								&new_preset,
								atlas,
							)
						}
					}
				}
			}
		}
	}


	imgui.PopStyleColor(1)
}

mysterious_bottom_window :: proc(
	window_width: u32,
	window_height: u32,
	window: glfw.WindowHandle,
) {
	ctx := (^utils.SharedContext)(glfw.GetWindowUserPointer(window))

	imgui.SetNextWindowPos(
		imgui.Vec2{f32(window_width / 6), f32(2 * window_height / 3)},
		imgui.Cond.Always,
	)
	imgui.SetNextWindowSize(
		imgui.Vec2{f32(2 * window_width / 3), f32(window_height / 3)},
		imgui.Cond.Always,
	)
	if imgui.Begin("Tileset", nil, {.NoMove, .NoResize, .NoCollapse}) {
		if ctx.editing_preset != nil {
			preset_object := (^rendering.RenderObject)(ctx.editing_preset)
			atlas := (^atl.Atlas)(preset_object.data)

			i := 0
			for name, tile in atlas.tiles {
				tile_id := fmt.aprintf("%s_%s", atlas.header.name, name)
				texture := ctx.manager.texture_manager.textures[tile_id]

				texture_size_x := 64
				texture_size_y := 64 * texture.height / texture.width

				imgui.Image(u64(texture.id), imgui.Vec2{f32(texture_size_x), f32(texture_size_y)})
				imgui.SetItemTooltip(strings.clone_to_cstring(tile_id))

				if imgui.BeginDragDropSource({.SourceAllowNullID}) {
					payload := DraggedTexturePayload {
						texture_index = i32(tile.id),
						source        = DraggedTextureSource.FromTilemapEditor,
					}

					imgui.SetDragDropPayload("ITEM", &payload, size_of(DraggedTexturePayload))

					imgui.EndDragDropSource()
				}


				if i % 8 != 7 {
					imgui.SameLine()
				}

				i += 1
			}
		}
	}

	imgui.End()
}
