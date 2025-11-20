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

BASIC_TRIANGLE_VERTEX_SHADER_SOURCE :: "resources/shaders/01_basic/triangle.vert"
BASIC_TRIANGLE_FRAGMENT_SHADER_SOURCE :: "resources/shaders/01_basic/triangle.frag"

SPRITE_VERTEX_SHADER_SOURCE :: "resources/shaders/02_sprite/sprite.vert"
SPRITE_FRAGMENT_SHADER_SOURCE :: "resources/shaders/02_sprite/sprite.frag"

CHARACTER_TEXTURE_PATH :: "resources/textures/character.png"

render_triangle :: proc() -> u32 {
	vertices := [?]f32{0.0, 0.5, 0.0, -0.5, -0.5, 0.0, 0.5, -0.5, 0.0}
	indices := [?]u32{0, 1, 2}

	vao, vbo, ebo: u32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)

	gl.BindVertexArray(vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(&vertices), gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), raw_data(&indices), gl.STATIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	fmt.println("2D triangle rendering setup complete.")

	return vao
}

initialize_renderer :: proc(manager: ^rm.ResourceManager) -> RendererContext {
	rm.load_shader(manager, "sprite", SPRITE_VERTEX_SHADER_SOURCE, SPRITE_FRAGMENT_SHADER_SOURCE)

	projection := utils.orthographic_projection_matrix(0.0, 800.0, 600.0, 0.0, -1.0, 1.0)

	shader := rm.get_shader(manager, "sprite")
	rm.use_shader(&shader)
	rm.set_matrix4("projection", &projection, &shader)
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
