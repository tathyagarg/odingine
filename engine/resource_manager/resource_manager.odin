package rm

import gl "vendor:OpenGL"
import stb "vendor:stb/image"

import "core:fmt"
import "core:strings"

import atl "../atlas"
import "../rendering/internal"

ResourceManager :: struct {
	shaders:  map[string]Shader,
	textures: map[string]Texture,
}

Shader :: struct {
	id: u32,
}

Texture :: struct {
	id:              u32,
	width:           i32,
	height:          i32,
	internal_format: i32,
	image_format:    u32,
	wrap_s:          i32,
	wrap_t:          i32,
	filter_min:      i32,
	filter_max:      i32,
}

initialize_resource_manager :: proc() -> ResourceManager {
	rm: ResourceManager
	rm.shaders = map[string]Shader{}
	rm.textures = map[string]Texture{}
	return rm
}

get_shader :: proc(rm: ^ResourceManager, name: string) -> Shader {
	if shader, exists := rm.shaders[name]; exists {
		return shader
	} else {
		fmt.eprintfln("Shader not found: %s\n", name)
		return Shader{}
	}
}

load_shader :: proc(
	rm: ^ResourceManager,
	name: string,
	vertex_source: string,
	fragment_source: string,
	geometry_source: string = "",
) -> Shader {
	if shader, exists := rm.shaders[name]; exists {
		return shader
	}

	shader_program := load_shader_from_source(vertex_source, fragment_source, geometry_source)
	rm.shaders[name] = shader_program
	return shader_program
}

load_shader_from_source :: proc(
	vertex_source: string,
	fragment_source: string,
	geometry_source: string = "",
) -> Shader {
	shader: Shader

	vertex_code := strings.clone_to_cstring(vertex_source)
	fragment_code := strings.clone_to_cstring(fragment_source)
	geometry_code := strings.clone_to_cstring(geometry_source)

	compile_shader(&shader, &vertex_code, &fragment_code, &geometry_code)

	return shader
}

compile_shader :: proc(
	shader: ^Shader,
	vertex_source: ^cstring,
	fragment_source: ^cstring,
	geometry_source: ^cstring = nil,
) {
	geometry_shader: u32

	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, vertex_source, nil)
	gl.CompileShader(vertex_shader)
	if !internal.verify_shader_status(vertex_shader) {
		fmt.eprintfln("Vertex shader compilation failed.\n")
	}

	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, fragment_source, nil)
	gl.CompileShader(fragment_shader)
	if !internal.verify_shader_status(fragment_shader) {
		fmt.eprintfln("Fragment shader compilation failed.\n")
	}

	if (geometry_source != nil) {
		geometry_shader := gl.CreateShader(gl.GEOMETRY_SHADER)
		gl.ShaderSource(geometry_shader, 1, geometry_source, nil)
		gl.CompileShader(geometry_shader)
		if !internal.verify_shader_status(geometry_shader) {
			fmt.eprintfln("Geometry shader compilation failed.\n")
		}
	}

	shader.id = gl.CreateProgram()
	gl.AttachShader(shader.id, vertex_shader)
	gl.AttachShader(shader.id, fragment_shader)

	if (geometry_source != nil) {
		gl.AttachShader(shader.id, geometry_shader)
	}

	gl.LinkProgram(shader.id)
	if !internal.verify_program_status(shader.id) {
		fmt.eprintfln("Shader program linking failed.\n")
	}

	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)
	if (geometry_source != nil) {
		gl.DeleteShader(geometry_shader)
	}
}

use_shader :: proc(shader: ^Shader) {
	gl.UseProgram(shader.id)
}

set_matrix4 :: proc(name: string, m: ^matrix[4, 4]f32, shader: ^Shader) {
	location := gl.GetUniformLocation(shader.id, strings.clone_to_cstring(name))
	gl.UniformMatrix4fv(location, 1, gl.FALSE, raw_data(m))
}

set_vector3 :: proc(name: string, v: [3]f32, shader: ^Shader) {
	gl.Uniform3f(
		gl.GetUniformLocation(shader.id, strings.clone_to_cstring(name)),
		v[0],
		v[1],
		v[2],
	)
}

set_integer :: proc(name: string, value: i32, shader: ^Shader) {
	location := gl.GetUniformLocation(shader.id, strings.clone_to_cstring(name))
	gl.Uniform1i(location, value)
}

generate_texture :: proc(texture: ^Texture, width: i32, height: i32, data: [^]u8) {
	texture.width = width
	texture.height = height

	gl.BindTexture(gl.TEXTURE_2D, texture.id)
	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		texture.internal_format,
		width,
		height,
		0,
		texture.image_format,
		gl.UNSIGNED_BYTE,
		data,
	)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, texture.wrap_s)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, texture.wrap_t)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, texture.filter_min)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, texture.filter_max)

	gl.BindTexture(gl.TEXTURE_2D, 0)
}

load_texture :: proc(
	rm: ^ResourceManager,
	name: string,
	file: string,
	alpha: bool = true,
) -> Texture {
	if tex_id, exists := rm.textures[name]; exists {
		return rm.textures[name]
	}

	texture := load_texture_from_file(strings.clone_to_cstring(file), alpha)
	rm.textures[name] = texture
	return texture
}

get_texture :: proc(rm: ^ResourceManager, name: string) -> Texture {
	if texture, exists := rm.textures[name]; exists {
		return texture
	} else {
		fmt.eprintfln("Texture not found: %s\n", name)
		return Texture{}
	}
}

load_texture_from_file :: proc(file: cstring, alpha: bool) -> Texture {
	texture: Texture = Texture {
		width           = 0,
		height          = 0,
		internal_format = gl.RGBA,
		image_format    = gl.RGBA,
		wrap_s          = gl.REPEAT,
		wrap_t          = gl.REPEAT,
		filter_min      = gl.NEAREST,
		filter_max      = gl.NEAREST,
	}

	gl.GenTextures(1, &texture.id)

	if alpha {
		texture.internal_format = gl.RGBA
		texture.image_format = gl.RGBA
	} else {
		texture.internal_format = gl.RGB
		texture.image_format = gl.RGB
	}

	width, height, nrChannels: i32

	data := stb.load(file, &width, &height, &nrChannels, 4)

	generate_texture(&texture, width, height, data)
	stb.image_free(data)

	return texture
}

load_atlas :: proc(rm: ^ResourceManager, atlas: atl.Atlas) -> map[string]Texture {
	textures := load_textures_from_atlas(atlas)

	for name, _ in atlas.tiles {
		rm.textures[name] = textures[name]
	}

	return textures
}

load_textures_from_atlas :: proc(atlas: atl.Atlas) -> map[string]Texture {
	textures: map[string]Texture = make(map[string]Texture, atlas.header.sprite_count)

	tile_width := i32(atlas.header.sprite_size[0])
	tile_height := i32(atlas.header.sprite_size[1])

	image_data: [^]u8
	width: i32
	height: i32
	nrChannels: i32

	image_data = stb.load(atlas.header.filename, &width, &height, &nrChannels, 4)
	if image_data == nil {
		fmt.eprintfln("Failed to load texture atlas: %s\n", atlas.header.filename)
		return textures
	}

	tiles_x := width / tile_width
	tiles_y := height / tile_height

	for y: i32 = 0; y < tiles_y; y += 1 {
		for x: i32 = 0; x < tiles_x; x += 1 {
			if (y * tiles_x) + x >= i32(atlas.header.sprite_count) {
				break
			}

			tile_data: [^]u8 = raw_data(make([]u8, tile_width * tile_height * 4)[:])

			for row: i32 = 0; row < tile_height; row += 1 {
				src_start := ((y * tile_height + row) * width + (x * tile_width)) * 4
				dest_start := row * tile_width * 4
				copy(
					tile_data[dest_start:dest_start + tile_width * 4],
					image_data[src_start:src_start + tile_width * 4],
				)
			}

			texture: Texture = Texture {
				width           = tile_width,
				height          = tile_height,
				internal_format = gl.RGBA,
				image_format    = gl.RGBA,
				wrap_s          = gl.REPEAT,
				wrap_t          = gl.REPEAT,
				filter_min      = gl.NEAREST,
				filter_max      = gl.NEAREST,
			}

			gl.GenTextures(1, &texture.id)
			generate_texture(&texture, tile_width, tile_height, tile_data)

			// Find the name corresponding to this tile index
			for name, tile in atlas.tiles {
				if i32(tile.position[0]) / tile_width == x &&
				   i32(tile.position[1]) / tile_height == y {
					textures[name] = texture
					break
				}
			}
		}
	}

	stb.image_free(image_data)
	return textures
}
