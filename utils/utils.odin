package utils

import "core:fmt"
import "core:os"
import "core:strings"

import "vendor:glfw"

import atl "../engine/atlas"
import rm "../engine/resource_manager"
import "./globals"

ArgumentDescriptor :: struct {
	name:      string,
	offset:    uintptr,
	type_info: typeid,
}

ScriptProc :: proc(
	state: ^SharedContext,
	target: globals.RenderObjectHandle,
	action: i32,
	args: rawptr,
)

RegisteredScript :: struct {
	script: globals.ScriptHandle,
	target: globals.RenderObjectHandle,
}

ScriptManager :: struct {
	scripts:            []globals.ScriptHandle,
	registered_scripts: map[i32][dynamic]RegisteredScript,
}


AddObject :: struct {
	name:           cstring,
	texture_source: cstring,
	position:       [2]f32,
	layer:          i32,
}

AddAtlas :: struct {
	name:     cstring,
	filepath: cstring,
}

SharedContext :: struct {
	game_focused:   bool,
	window_size:    [2]i32,
	atlases:        map[string]^atl.Atlas,
	event_handlers: map[string]proc(state: ^SharedContext, args: ..any) -> ErrorMessage,
	manager:        ^rm.ResourceManager,
	render_context: globals.RendererContextHandle,
	add_object:     AddObject,
	add_atlas:      AddAtlas,
	error_message:  string,
	focused_object: globals.RenderObjectHandle,
	key_listeners:  map[int]proc(state: ^SharedContext, action: int),
	script_manager: ScriptManager,
}

ErrorMessage :: enum {
	None,
	FailedToLoadAtlas,
	FailedToSaveAtlas,
	FailedToLoadTexture,
	FailedToAddObject,
	EmptyNameOrTextureSource,
}

default_shared_context :: proc() -> SharedContext {
	addobject_texture_source := strings.unsafe_string_to_cstring(string(make([]u8, 256)[:0]))
	addobject_name := strings.unsafe_string_to_cstring(string(make([]u8, 256)[:0]))

	return SharedContext {
		game_focused = false,
		window_size = [2]i32{800, 600},
		atlases = map[string]^atl.Atlas{},
		event_handlers = map[string]proc(state: ^SharedContext, args: ..any) -> ErrorMessage{},
		manager = nil,
		render_context = nil,
		add_object = AddObject {
			name = addobject_name,
			texture_source = addobject_texture_source,
			position = [2]f32{0.0, 0.0},
			layer = 0,
		},
		add_atlas = AddAtlas {
			name = strings.unsafe_string_to_cstring(string(make([]u8, 64)[:0])),
			filepath = strings.unsafe_string_to_cstring(string(make([]u8, 256)[:0])),
		},
		error_message = "",
		focused_object = nil,
		key_listeners = map[int]proc(state: ^SharedContext, action: int){},
		script_manager = ScriptManager {
			scripts = []globals.ScriptHandle{},
			registered_scripts = map[i32][dynamic]RegisteredScript{},
		},
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
	textures: map[string]^rm.Texture,
	index: globals.TextureType,
) -> ^rm.Texture {
	i := 0
	for _, texture in textures {
		if i == int(index) {
			return texture
		}
		i += 1
	}
	return nil
}

empty_cstring :: proc(length: int) -> cstring {
	return strings.unsafe_string_to_cstring(string(make([]u8, length)[:0]))
}
