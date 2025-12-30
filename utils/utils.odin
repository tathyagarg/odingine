package utils

import "core:fmt"
import "core:os"
import "core:strings"

import "vendor:glfw"

import rm "../engine/resource_manager"
import "./globals"

ArgumentDescriptor :: struct {
	name:      string,
	offset:    uintptr,
	type_info: typeid,
	tooltip:   string,
}

ScriptProc :: proc(state: ^SharedContext, target: globals.RenderObjectHandle, args: rawptr)

RegisteredScript :: struct {
	script: globals.ScriptHandle,
	target: globals.RenderObjectHandle,
}

ScriptManager :: struct {
	scripts:            []globals.ScriptHandle,
	registered_scripts: [dynamic]RegisteredScript,
}

AddObject :: struct {
	name:     cstring,
	texture:  globals.TextureType,
	position: [2]f32,
	layer:    i32,
}

AddAtlas :: struct {
	filepath: cstring,
}

AddPreset :: struct {
	atlas_name:  i32,
	preset_name: i32,
	layer_index: i32,
	offset:      [2]f32,
}

AddTexture :: struct {
	name:   cstring,
	source: cstring,
}

Camera :: struct {
	position: [2]f32,
	zoom:     f32,
}

// ts holding the entire codebase together
SharedContext :: struct {
	game_focused:   bool,
	editing_preset: globals.RenderObjectHandle,
	window_size:    [2]i32,
	event_handlers: map[string]proc(state: ^SharedContext, args: ..any) -> ErrorMessage,
	manager:        ^rm.ResourceManager,
	render_context: globals.RendererContextHandle,
	add_object:     AddObject,
	add_atlas:      AddAtlas,
	add_texture:    AddTexture,
	add_preset:     AddPreset,
	error_message:  string,
	focused_object: globals.RenderObjectHandle,
	script_manager: ScriptManager,
	open_popups:    map[string]bool,
	key_state:      map[i32]bool,
	camera:         Camera,
}

ErrorMessage :: enum {
	None,
	FailedToLoadAtlas,
	FailedToSaveAtlas,
	FailedToLoadTexture,
	FailedToAddObject,
	EmptyNameOrTextureSource,
	FailedToSaveProject,
}

default_shared_context :: proc() -> SharedContext {
	return SharedContext {
		game_focused = false,
		window_size = [2]i32{800, 600},
		event_handlers = map[string]proc(state: ^SharedContext, args: ..any) -> ErrorMessage{},
		manager = nil,
		render_context = nil,
		add_object = AddObject {
			name = empty_cstring(64),
			texture = 0,
			position = [2]f32{0.0, 0.0},
			layer = 0,
		},
		add_atlas = AddAtlas{filepath = empty_cstring(256)},
		add_texture = AddTexture{name = empty_cstring(64), source = empty_cstring(256)},
		add_preset = AddPreset {
			atlas_name = 0,
			preset_name = 0,
			layer_index = 0,
			offset = [2]f32{0.0, 0.0},
		},
		error_message = "",
		focused_object = nil,
		script_manager = ScriptManager {
			scripts = []globals.ScriptHandle{},
			registered_scripts = [dynamic]RegisteredScript{},
		},
		open_popups = map[string]bool{},
		key_state = map[i32]bool{},
		camera = Camera{position = [2]f32{0, 0}, zoom = 1.0},
	}
}

terminate :: proc(message: string = "Terminating application due to an error.") {
	fmt.println(message)
	glfw.Terminate()
	os.exit(1)
}

orthographic_projection_matrix :: proc(
	left: f32,
	right: f32,
	bottom: f32,
	top: f32,
	near: f32,
	far: f32,
) -> matrix[4, 4]f32 {
	result: matrix[4, 4]f32

	result[0][0] = 2.0 / (right - left)
	result[1][1] = 2.0 / (top - bottom)
	result[2][2] = -2.0 / (far - near)
	result[3][0] = -(right + left) / (right - left)
	result[3][1] = -(top + bottom) / (top - bottom)
	result[3][2] = -(far + near) / (far - near)
	result[3][3] = 1.0

	return result
}

// Window coordinates are in range (0, w) and (0, h) with (0,0) at bottom-left
// Screen coordinates are in range (0, 2w), (0, 2h) with (0,0) at top-left
window_to_screen_coordinates :: proc(
	raw_window_size: [2]i32,
	window_size: [2]i32,
	window_coords: [2]f32,
) -> [2]f32 {
	scale_x := f32(raw_window_size[0]) / f32(window_size[0])
	scale_y := f32(raw_window_size[1]) / f32(window_size[1])

	screen_x := window_coords[0] * scale_x
	screen_y := (f32(window_size[1]) - window_coords[1]) * scale_y

	return [2]f32{screen_x, screen_y}
}

texture_at_index :: proc(
	texture_manager: ^rm.TextureManager,
	index: globals.TextureType,
) -> ^rm.Texture {
	if index < 0 || index >= globals.TextureType(len(texture_manager.keys)) {
		return nil
	}
	return texture_manager.textures[texture_manager.keys[index]]
}

empty_cstring :: proc(length: int) -> cstring {
	return strings.unsafe_string_to_cstring(string(make([]u8, length)[:0]))
}

make_grid :: proc(n: int, cell: f32) -> ([]f32, int) {
	count := n * 4
	verts := make([]f32, count * 2)

	index := 0
	size := f32(n) * cell

	for i in 0 ..< n {
		pos := f32(i) * cell

		// Vertical line
		verts[index] = pos
		verts[index + 1] = 0.0
		verts[index + 2] = pos
		verts[index + 3] = size
		index += 4

		// Horizontal line
		verts[index] = 0.0
		verts[index + 1] = pos
		verts[index + 2] = size
		verts[index + 3] = pos
		index += 4
	}

	return verts, index / 2
}
