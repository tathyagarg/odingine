package utils

import "core:fmt"
import "core:os"

import "vendor:glfw"

import atl "../engine/atlas"
import rendering "../engine/rendering"
import rm "../engine/resource_manager"

DevelopmentState :: struct {
	game_focused:   bool,
	atlases:        map[string]^atl.Atlas,
	event_handlers: map[string]proc(state: ^DevelopmentState),
	manager:        ^rm.ResourceManager,
	render_context: ^rendering.RendererContext,
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
