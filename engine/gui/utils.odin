package gui

import "core:fmt"
import "core:strings"

import imgui "../../third_party/imgui"
import "../../utils"
import "../../utils/globals"
import rm "../resource_manager"
import "../scripts"

DraggedTextureSource :: enum {
	FromTextureBrowser,
	FromTilemapEditor,
}

DraggedTexturePayload :: struct {
	texture_index: i32,
	source:        DraggedTextureSource,
}

load_texture_popup :: proc(ctx: ^utils.SharedContext) {
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
	ctx: ^utils.SharedContext = nil,
	update_callback: proc(selected_index: ^i32, ctx: ^utils.SharedContext) = nil,
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
					if update_callback != nil {
						update_callback(selected_index, ctx)
					}
				}
				imgui.PopID()
			}
		}
		imgui.EndCombo()
	}

	imgui.PopID()
}

tooltip :: proc(name: string, description: string) {
	if (imgui.BeginItemTooltip()) {
		imgui.PushTextWrapPos(imgui.GetFontSize() * 35.0)
		imgui.Text(
			strings.clone_to_cstring(
				fmt.aprintf("%s\n%s\n%s", name, strings.repeat("-", len(name)), description),
			),
		)
		imgui.PopTextWrapPos()
		imgui.EndTooltip()
	}
}

texture_input :: proc(
	combo_id: cstring,
	label: cstring,
	options: []string,
	ptr: ^scripts.TextureType,
	texture_manager: ^rm.TextureManager,
) {
	if i32(len(texture_manager.keys)) > i32((^globals.TextureType)(ptr)^) {
		imgui.Image(
			u64(utils.texture_at_index(texture_manager, (^globals.TextureType)(ptr)^).id),
			imgui.Vec2{16, 16},
		)

		imgui.SameLine()
	}

	findable_combo_input(combo_id, label, options, (^i32)(ptr))
}
