package render2d

import "core:fmt"

import gl "vendor:OpenGL"

import rm ".."
import "../../utils"

RendererContext :: struct {
	vao:            u32,
	shader_program: rm.Shader,
}

BASIC_TRIANGLE_VERTEX_SHADER_SOURCE :: "resources/shaders/01_basic/triangle.vert"
BASIC_TRIANGLE_FRAGMENT_SHADER_SOURCE :: "resources/shaders/01_basic/triangle.frag"

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
	vao := render_triangle()

	shader_program := rm.load_shader(
		manager,
		"BasicTriangleShader",
		BASIC_TRIANGLE_VERTEX_SHADER_SOURCE,
		BASIC_TRIANGLE_FRAGMENT_SHADER_SOURCE,
	)

	return RendererContext{vao = vao, shader_program = shader_program}
}

render :: proc(ctx: ^RendererContext) {
	gl.ClearColor(0.2, 0.3, 0.3, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.UseProgram(ctx.shader_program.id)
	gl.BindVertexArray(ctx.vao)
	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
}

cleanup_renderer :: proc(ctx: ^RendererContext) {
	gl.DeleteVertexArrays(1, &ctx.vao)
	gl.DeleteProgram(ctx.shader_program.id)
}

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
		return width / 4, height / 3, width / 2, 2 * height / 3
	} else {
		return 0, 0, width, height
	}
}
