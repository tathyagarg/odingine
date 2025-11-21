package rendering

import "core:fmt"

import gl "vendor:OpenGL"

import "../../utils"
import render_sprite "../rendering/sprite"
import rm "../resource_manager"

RenderObject :: struct {
	sprite:   render_sprite.Sprite,
	texture:  rm.Texture,
	position: [2]f32,
	size:     [2]f32,
	rotation: f32,
}

RendererContext :: struct {
	manager: ^rm.ResourceManager,
	objects: [dynamic]RenderObject,
}

initialize_renderer :: proc(
	manager: ^rm.ResourceManager,
	sprite_vertex_shader: string,
	sprite_fragment_shader: string,
	projection: ^matrix[4, 4]f32,
) -> RendererContext {
	rm.load_shader(manager, "sprite", sprite_vertex_shader, sprite_fragment_shader)

	shader := rm.get_shader(manager, "sprite")
	rm.use_shader(&shader)
	rm.set_matrix4("projection", projection, &shader)
	rm.set_integer("image", 0, &shader)

	objects := [dynamic]RenderObject{}
	return RendererContext{manager = manager, objects = objects}
}

render :: proc(ctx: ^RendererContext) {
	gl.ClearColor(0.2, 0.3, 0.3, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	for &object in ctx.objects {
		render_sprite.draw_sprite(
			ctx.manager,
			&object.sprite,
			&object.texture,
			object.position,
			object.size,
			object.rotation,
		)
	}
}

cleanup_renderer :: proc(ctx: ^RendererContext) {}

get_scissor_bounds :: proc(
	env: utils.Environment,
	width: i32,
	height: i32,
) -> (
	i32,
	i32,
	i32,
	i32,
) {
	if env == .Development {
		return width / 6, height / 3, 2 * width / 3, 2 * height / 3
	} else {
		return 0, 0, width, height
	}
}
