package render_sprite

import "core:fmt"
import "core:math/linalg"

import gl "vendor:OpenGL"

import atl "../../atlas"
import mat_math "../../math/matrix"
import rm "../../resource_manager"

FLOATS_PER_VERTEX :: 4
VERTICES_PER_TILE :: 6
FLOATS_PER_TILE :: (FLOATS_PER_VERTEX * VERTICES_PER_TILE)

Sprite :: struct {
	shader:       rm.Shader,
	quad_vao:     u32,
	vbo:          u32,
	vertex_count: i32,
	hovered:      bool,
}

SQUARE_VERTICES :: [?]f32 {
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

initialize_sprite :: proc(manager: ^rm.ResourceManager, shader: ^rm.Shader) -> Sprite {
	sprite: Sprite
	sprite.shader = shader^
	sprite.vertex_count = 6

	vertices := SQUARE_VERTICES

	gl.GenVertexArrays(1, &sprite.quad_vao)
	gl.GenBuffers(1, &sprite.vbo)

	gl.BindBuffer(gl.ARRAY_BUFFER, sprite.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(&vertices), gl.STATIC_DRAW)

	gl.BindVertexArray(sprite.quad_vao)
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * size_of(f32), 0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	return sprite
}

add_tile_quad :: proc(verts: []f32, idx: ^int, px, py: f32, uv: [4]f32, tile_w, tile_h: f32) {
	verts[idx^] = px
	verts[idx^ + 1] = py
	verts[idx^ + 2] = uv[0]
	verts[idx^ + 3] = uv[1]
	idx^ += 4

	verts[idx^] = px + tile_w
	verts[idx^ + 1] = py
	verts[idx^ + 2] = uv[2]
	verts[idx^ + 3] = uv[1]
	idx^ += 4

	verts[idx^] = px + tile_w
	verts[idx^ + 1] = py + tile_h
	verts[idx^ + 2] = uv[2]
	verts[idx^ + 3] = uv[3]
	idx^ += 4

	// Second tridx^angle
	verts[idx^] = px
	verts[idx^ + 1] = py
	verts[idx^ + 2] = uv[0]
	verts[idx^ + 3] = uv[1]
	idx^ += 4

	verts[idx^] = px + tile_w
	verts[idx^ + 1] = py + tile_h
	verts[idx^ + 2] = uv[2]
	verts[idx^ + 3] = uv[3]
	idx^ += 4

	verts[idx^] = px
	verts[idx^ + 1] = py + tile_h
	verts[idx^ + 2] = uv[0]
	verts[idx^ + 3] = uv[3]
	idx^ += 4
}

add_isometric_tile_quad :: proc(
	verts: []f32,
	idx: ^int,
	px, py: f32,
	uv: [4]f32,
	tile_w, tile_h: f32,
) {
	half_w := tile_w / 1.0
	half_h := tile_h / 2.0

	s_x := (px - py) * 0.5
	s_y := (px + py) * 0.25

	verts[idx^] = s_x
	verts[idx^ + 1] = s_y
	verts[idx^ + 2] = uv[0]
	verts[idx^ + 3] = uv[1]
	idx^ += 4

	verts[idx^] = s_x + half_w
	verts[idx^ + 1] = s_y + half_h
	verts[idx^ + 2] = uv[2]
	verts[idx^ + 3] = uv[1]
	idx^ += 4

	verts[idx^] = s_x
	verts[idx^ + 1] = s_y + (2 * half_h)
	verts[idx^ + 2] = uv[2]
	verts[idx^ + 3] = uv[3]
	idx^ += 4

	// Second triangle
	verts[idx^] = s_x
	verts[idx^ + 1] = s_y
	verts[idx^ + 2] = uv[0]
	verts[idx^ + 3] = uv[1]
	idx^ += 4

	verts[idx^] = s_x
	verts[idx^ + 1] = s_y + (2 * half_h)
	verts[idx^ + 2] = uv[2]
	verts[idx^ + 3] = uv[3]
	idx^ += 4

	verts[idx^] = s_x - half_w
	verts[idx^ + 1] = s_y + half_h
	verts[idx^ + 2] = uv[0]
	verts[idx^ + 3] = uv[3]
	idx^ += 4
}

get_uv :: proc(atlas: ^atl.Atlas, tile_id: int) -> [4]f32 {
	tile_w := atlas.header.sprite_size[0]
	tile_h := atlas.header.sprite_size[1]

	atlas_w := atlas.header.atlas_size[0] * tile_w
	atlas_h := atlas.header.atlas_size[1] * tile_h

	columns := atlas.header.atlas_size[0]

	atlas_loc_x := tile_id % columns
	atlas_loc_y := tile_id / columns

	pixel_x0 := atlas_loc_x * tile_w
	pixel_y0 := atlas_loc_y * tile_h

	pixel_x1 := (atlas_loc_x + 1) * tile_w
	pixel_y1 := (atlas_loc_y + 1) * tile_h

	u0 := f32(pixel_x0) / f32(atlas_w)
	v0 := f32(pixel_y0) / f32(atlas_h)

	u1 := f32(pixel_x1) / f32(atlas_w)
	v1 := f32(pixel_y1) / f32(atlas_h)

	return [4]f32{u0, v0, u1, v1}
}

initialize_preset :: proc(
	manager: ^rm.ResourceManager,
	shader: ^rm.Shader,
	preset: ^atl.Preset,
	atlas: ^atl.Atlas,
) -> Sprite {
	preset_w := preset.size[0]
	preset_h := preset.size[1]

	tile_h := f32(atlas.header.sprite_size[1])
	tile_w := f32(atlas.header.sprite_size[0])

	sprite: Sprite
	sprite.shader = shader^

	verts := make([]f32, preset_w * preset_h * FLOATS_PER_TILE)
	index := 0

	for tile_y in 0 ..< preset_h {
		for tile_x in 0 ..< preset_w {
			tile := preset.tile_ids[tile_x + tile_y * preset_w]

			uv := get_uv(atlas, tile)
			px, py := f32(tile_x) * tile_w, f32(tile_y) * tile_h

			// add_isometric_tile_quad(verts, &index, px, py, uv, tile_w, tile_h)
			add_tile_quad(verts, &index, px, py, uv, tile_w, tile_h)
		}
	}

	fmt.println("verts: ", verts)

	for vert, i in verts {
		if i % 4 == 0 {
			verts[i] *= 1 / (tile_w * f32(preset_w))
		}

		if i % 4 == 1 {
			verts[i] *= 1 / (tile_h * f32(preset_h))
		}
	}

	fmt.println("verts: ", verts)

	sprite.vertex_count = i32(index) / FLOATS_PER_VERTEX

	gl.GenVertexArrays(1, &sprite.quad_vao)
	gl.GenBuffers(1, &sprite.vbo)

	gl.BindVertexArray(sprite.quad_vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, sprite.vbo)

	stride := i32(FLOATS_PER_VERTEX * size_of(f32))

	gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, stride, uintptr(0))
	gl.EnableVertexAttribArray(0)

	gl.BufferData(gl.ARRAY_BUFFER, len(verts) * size_of(f32), raw_data(verts), gl.STATIC_DRAW)

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
	rm.set_integer("hovered", 1 if sprite.hovered else 0, &sprite.shader)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, texture.id)

	gl.BindVertexArray(sprite.quad_vao)

	gl.DrawArrays(gl.TRIANGLES, 0, sprite.vertex_count)
	gl.BindVertexArray(0)
}
