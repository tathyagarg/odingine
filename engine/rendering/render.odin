package rendering

import "core:strings"

import gl "vendor:OpenGL"

import "../../utils/globals"
import render_sprite "../rendering/sprite"
import rm "../resource_manager"

RenderObject :: struct {
	sprite:   render_sprite.Sprite,
	texture:  ^rm.Texture,
	position: [2]f32,
	size:     [2]f32,
	rotation: f32,
}

RenderLayer :: struct {
	name:    cstring,
	objects: [dynamic]RenderObject,
	z_layer: i32,
}

RendererContext :: struct {
	manager: ^rm.ResourceManager,
	layers:  [dynamic]RenderLayer,
	// objects: [dynamic]RenderObject,
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

	layers: [dynamic]RenderLayer = {}
	return RendererContext{manager = manager, layers = layers}
}

render :: proc(ctx: ^RendererContext) {
	gl.ClearColor(0.2, 0.3, 0.3, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	for &layer in ctx.layers {
		for &object in layer.objects {
			render_sprite.draw_sprite(
				ctx.manager,
				&object.sprite,
				object.texture,
				object.position,
				object.size,
				object.rotation,
			)
		}
	}
}

cleanup_renderer :: proc(ctx: ^RendererContext) {}

get_scissor_bounds :: proc(
	env: globals.Environment,
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

add_layer :: proc(ctx: ^RendererContext, name: string, z_layer: i32) {
	layer_name := strings.unsafe_string_to_cstring(name)
	new_layer := RenderLayer {
		name    = layer_name,
		objects = [dynamic]RenderObject{},
		z_layer = z_layer,
	}
	append(&ctx.layers, new_layer)
}
