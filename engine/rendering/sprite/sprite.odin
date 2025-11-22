package render_sprite

import "core:math/linalg"

import gl "vendor:OpenGL"

import mat_math "../../math/matrix"
import rm "../../resource_manager"

Sprite :: struct {
	shader:   rm.Shader,
	quad_vao: u32,
}

initialize_sprite :: proc(manager: ^rm.ResourceManager, shader: ^rm.Shader) -> Sprite {
	vbo: u32

	sprite: Sprite
	sprite.shader = shader^

	vertices := [?]f32 {
		0.0,
		1.0,
		0.0,
		1.0,
		1.0,
		0.0,
		1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		1.0,
		0.0,
		1.0,
		1.0,
		1.0,
		1.0,
		1.0,
		1.0,
		0.0,
		1.0,
		0.0,
	}

	gl.GenVertexArrays(1, &sprite.quad_vao)
	gl.GenBuffers(1, &vbo)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(&vertices), gl.STATIC_DRAW)

	gl.BindVertexArray(sprite.quad_vao)
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	return sprite
}


draw_sprite :: proc(
	manager: ^rm.ResourceManager,
	sprite: ^Sprite,
	texture: ^rm.Texture,
	position: [2]f32,
	size: [2]f32,
	rotation: f32,
) {
	if texture == nil {
		return
	}

	rm.use_shader(&sprite.shader)

	model := linalg.MATRIX4F32_IDENTITY

	model = mat_math.translate(model, [3]f32{position[0], position[1], 0.0})
	model = mat_math.translate(model, [3]f32{0.5 * size[0], 0.5 * size[1], 0.0})
	model = mat_math.rotate(model, rotation, [3]f32{0.0, 0.0, 1.0})
	model = mat_math.translate(model, [3]f32{-0.5 * size[0], -0.5 * size[1], 0.0})

	model = mat_math.scale(model, [3]f32{size[0], size[1], 1.0})

	rm.set_matrix4("model", &model, &sprite.shader)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)

	gl.BindVertexArray(sprite.quad_vao)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
	gl.BindVertexArray(0)
}
