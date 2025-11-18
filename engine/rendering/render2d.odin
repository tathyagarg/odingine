package render2d

import "core:fmt"

import gl "vendor:OpenGL"

import "../../utils"
import "internal"

vertex_shader_source: cstring = `#version 330 core
layout (location = 0) in vec3 aPos;
void main()
{
   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}
`

fragment_shader_source: cstring = `#version 330 core
out vec4 FragColor;
void main()
{
   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
}
`

Render2DContext :: struct {
	vao:            u32,
	shader_program: u32,
}

render_triangle :: proc() -> (u32, u32) {
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vertex_shader_source, nil)
	gl.CompileShader(vertex_shader)

	if !internal.verify_shader_status(vertex_shader) do utils.terminate("Vertex shader compilation failed.")

	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, &fragment_shader_source, nil)
	gl.CompileShader(fragment_shader)

	if !internal.verify_shader_status(fragment_shader) do utils.terminate("Fragment shader compilation failed.")

	shader_program := gl.CreateProgram()
	gl.AttachShader(shader_program, vertex_shader)
	gl.AttachShader(shader_program, fragment_shader)
	gl.LinkProgram(shader_program)

	success: i32
	gl.GetProgramiv(shader_program, gl.LINK_STATUS, &success)

	if success != 1 {
		fmt.println("Shader program linking failed.")
		utils.terminate()
	}

	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

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

	return vao, shader_program
}

initialize_render2d :: proc() -> Render2DContext {
	vao, shader_program := render_triangle()
	return Render2DContext{vao = vao, shader_program = shader_program}
}

render2d :: proc(ctx: ^Render2DContext) {
	gl.UseProgram(ctx.shader_program)
	gl.BindVertexArray(ctx.vao)
	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
}

cleanup_render2d :: proc(ctx: ^Render2DContext) {
	gl.DeleteVertexArrays(1, &ctx.vao)
	gl.DeleteProgram(ctx.shader_program)
}
