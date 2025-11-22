package utils

import "core:fmt"
import "core:os"
import "core:strings"

import "vendor:glfw"

import atl "../engine/atlas"
import rendering "../engine/rendering"
import rm "../engine/resource_manager"

AddObject :: struct {
	name:           cstring,
	texture_source: cstring,
	position:       [2]f32,
	layer:          i32,
}

DevelopmentState :: struct {
	game_focused:   bool,
	atlases:        map[string]^atl.Atlas,
	event_handlers: map[string]proc(state: ^DevelopmentState, args: ..any) -> ErrorMessage,
	manager:        ^rm.ResourceManager,
	render_context: ^rendering.RendererContext,
	add_object:     AddObject,
	error_message:  string,
}

ErrorMessage :: enum {
	None,
	FailedToLoadAtlas,
	FailedToSaveAtlas,
	FailedToLoadTexture,
	FailedToAddObject,
	EmptyNameOrTextureSource,
}

default_development_state :: proc() -> DevelopmentState {
	addobject_texture_source := strings.unsafe_string_to_cstring(string(make([]u8, 256)[:0]))
	addobject_name := strings.unsafe_string_to_cstring(string(make([]u8, 256)[:0]))

	return DevelopmentState {
		game_focused = false,
		atlases = map[string]^atl.Atlas{},
		event_handlers = map[string]proc(state: ^DevelopmentState, args: ..any) -> ErrorMessage{},
		manager = nil,
		render_context = nil,
		add_object = AddObject {
			name = addobject_name,
			texture_source = addobject_texture_source,
			position = [2]f32{0.0, 0.0},
			layer = 0,
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
