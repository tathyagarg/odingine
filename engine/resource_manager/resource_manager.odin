package rm

import "core:path/filepath"
import gl "vendor:OpenGL"
import stb "vendor:stb/image"

import "core:fmt"
import "core:strings"

import atl "../atlas"
import "../rendering/internal"

TextureManager :: struct {
	keys:     [dynamic]string,
	textures: map[string]^Texture,
}

AtlasManager :: struct {
	keys:    [dynamic]string,
	atlases: map[string]^atl.Atlas,
}

ResourceManager :: struct {
	shaders:         map[string]Shader,
	texture_manager: TextureManager,
	preview_texture: ^Texture,
	atlas_manager:   AtlasManager,
}

Shader :: struct {
	id: u32,
}

Texture :: struct {
	id:              u32,
	name:            string,
	width:           i32,
	height:          i32,
	internal_format: i32,
	image_format:    u32,
	wrap_s:          i32,
	wrap_t:          i32,
	filter_min:      i32,
	filter_max:      i32,
}

initialize_resource_manager :: proc() -> ^ResourceManager {
	rm := new(ResourceManager)
	rm^ = ResourceManager {
		shaders = map[string]Shader{},
		texture_manager = TextureManager {
			keys = [dynamic]string{},
			textures = make(map[string]^Texture),
		},
		atlas_manager = AtlasManager {
			keys = [dynamic]string{},
			atlases = make(map[string]^atl.Atlas),
		},
		preview_texture = nil,
	}

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

assign_texture :: proc(rm: ^ResourceManager, name: string, texture: ^Texture) {
	rm.texture_manager.textures[name] = texture
	append(&rm.texture_manager.keys, name)
}

load_texture :: proc(
	rm: ^ResourceManager,
	name: string,
	file: string,
	alpha: bool = true,
) -> ^Texture {
	tex := load_texture_without_assign(rm, name, file, alpha)
	assign_texture(rm, name, tex)

	return tex
}

load_texture_without_assign :: proc(
	rm: ^ResourceManager,
	name: string,
	file: string,
	alpha: bool = true,
) -> ^Texture {
	if tex_id, exists := rm.texture_manager.textures[name]; exists {
		return rm.texture_manager.textures[name]
	}

	texture := load_texture_from_file(strings.clone_to_cstring(file), alpha)
	if texture == nil {
		fmt.eprintfln("Failed to load texture from file: %s\n", file)
		return nil
	}

	texture.name = name

	return texture
}

get_texture :: proc(rm: ^ResourceManager, name: string) -> ^Texture {
	if texture, exists := rm.texture_manager.textures[name]; exists {
		return rm.texture_manager.textures[name]
	} else {
		fmt.eprintfln("Texture not found: '%s'\n", name)
		return nil
	}
}

load_texture_from_file :: proc(file: cstring, alpha: bool) -> ^Texture {
	texture: ^Texture = new(Texture)
	texture.wrap_s = gl.REPEAT
	texture.wrap_t = gl.REPEAT
	texture.filter_min = gl.NEAREST
	texture.filter_max = gl.NEAREST

	// texture = Texture {
	// 	width           = 0,
	// 	height          = 0,
	// 	internal_format = gl.RGBA,
	// 	image_format    = gl.RGBA,
	// 	wrap_s          = gl.REPEAT,
	// 	wrap_t          = gl.REPEAT,
	// 	filter_min      = gl.NEAREST,
	// 	filter_max      = gl.NEAREST,
	// }

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
	if data == nil {
		return nil
	}

	generate_texture(texture, width, height, data)
	stb.image_free(data)

	return texture
}

load_atlas :: proc(rm: ^ResourceManager, atlas: ^atl.Atlas) -> ^Texture {
	texture := load_texture(
		rm,
		string(atlas.header.name),
		filepath.join({filepath.dir(string(atlas.source)), string(atlas.header.filename)}),
		true,
	)

	// textures := load_textures_from_atlas(atlas^)

	// for name, _ in atlas.tiles {
	// 	assign_texture(rm, name, textures[name])
	// }

	fmt.println("Loaded atlas: ", atlas)

	append(&rm.atlas_manager.keys, string(atlas.header.name))
	rm.atlas_manager.atlases[string(atlas.header.name)] = atlas

	fmt.println("Header: ", atlas.header)

	return texture
}

load_textures_from_atlas :: proc(atlas: atl.Atlas) -> map[string]^Texture {
	textures: map[string]^Texture = make(map[string]^Texture, atlas.header.sprite_count)

	tile_width := i32(atlas.header.sprite_size[0])
	tile_height := i32(atlas.header.sprite_size[1])

	image_data: [^]u8
	width: i32
	height: i32
	nrChannels: i32

	path := filepath.join({filepath.dir(string(atlas.source)), string(atlas.header.filename)})
	image_data = stb.load(strings.clone_to_cstring(path), &width, &height, &nrChannels, 4)
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

			texture: ^Texture = new(Texture)
			texture.width = tile_width
			texture.height = tile_height
			texture.internal_format = gl.RGBA
			texture.image_format = gl.RGBA
			texture.wrap_s = gl.REPEAT
			texture.wrap_t = gl.REPEAT
			texture.filter_min = gl.NEAREST
			texture.filter_max = gl.NEAREST

			gl.GenTextures(1, &texture.id)
			generate_texture(texture, tile_width, tile_height, tile_data)

			for name, tile in atlas.tiles {
				if i32(tile.position[0]) / tile_width == x &&
				   i32(tile.position[1]) / tile_height == y {
					texture.name = name
					textures[name] = texture
					break
				}
			}
		}
	}

	stb.image_free(image_data)
	return textures
}

update_textures_from_atlas :: proc(rm: ^ResourceManager, atlas: ^atl.Atlas) {
	image_data: [^]u8
	width: i32
	height: i32
	nrChannels: i32

	path := filepath.join({filepath.dir(string(atlas.source)), string(atlas.header.filename)})
	image_data = stb.load(strings.clone_to_cstring(path), &width, &height, &nrChannels, 4)
	if image_data == nil {
		fmt.eprintfln("Failed to load texture atlas: %s\n", atlas.header.filename)
		return
	}

	tile_width := i32(atlas.header.sprite_size[0])
	tile_height := i32(atlas.header.sprite_size[1])

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

			// Find the name corresponding to this tile index
			for name, tile in atlas.tiles {
				if i32(tile.position[0]) / tile_width == x &&
				   i32(tile.position[1]) / tile_height == y {
					if texture, exists := rm.texture_manager.textures[name]; exists {
						generate_texture(texture, tile_width, tile_height, tile_data)
					}
					break
				}
			}
		}
	}
}
