package rm

import gl "vendor:OpenGL"
import stb "vendor:stb/image"

import "core:fmt"
import "core:os"
import "core:strings"

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
	vertex_path: string,
	fragment_path: string,
	geometry_path: string = "",
) -> Shader {
	if shader, exists := rm.shaders[name]; exists {
		return shader
	}

	shader_program := load_shader_from_file(vertex_path, fragment_path, geometry_path)
	rm.shaders[name] = shader_program
	return shader_program
}

load_shader_from_file :: proc(
	vertex_path: string,
	fragment_path: string,
	geometry_path: string = "",
) -> Shader {
	geometry_source: cstring

	vertex_code, vertex_success := os.read_entire_file_from_filename(vertex_path)
	if !vertex_success {
		fmt.eprintfln("Failed to read vertex shader file: %s\n", vertex_path)
	}

	fragment_code, fragment_success := os.read_entire_file_from_filename(fragment_path)
	if !fragment_success {
		fmt.eprintfln("Failed to read fragment shader file: %s\n", fragment_path)
	}

	if (geometry_path != "") {
		geometry_code, geometry_success := os.read_entire_file_from_filename(geometry_path)
		if !geometry_success {
			fmt.eprintfln("Failed to read geometry shader file: %s\n", geometry_path)
		}
		geometry_source := strings.clone_to_cstring(string(geometry_code))
	}

	vertex_source := strings.clone_to_cstring(string(vertex_code))
	fragment_source := strings.clone_to_cstring(string(fragment_code))

	fmt.printfln("Vertex Shader Source:\n%s\n", vertex_path)
	fmt.printfln("Fragment Shader Source:\n%s\n", fragment_path)

	shader: Shader

	if (geometry_path != "") {
		compile_shader(&shader, &vertex_source, &fragment_source, &geometry_source)
	} else {
		compile_shader(&shader, &vertex_source, &fragment_source)
	}

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
	gl.UniformMatrix4fv(
		gl.GetUniformLocation(shader.id, strings.clone_to_cstring(name)),
		1,
		gl.FALSE,
		raw_data(m),
	)
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
	gl.Uniform1i(gl.GetUniformLocation(shader.id, strings.clone_to_cstring(name)), value)
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
	alpha: bool = false,
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
		internal_format = gl.RGB,
		image_format    = gl.RGB,
		wrap_s          = gl.REPEAT,
		wrap_t          = gl.REPEAT,
		filter_min      = gl.LINEAR,
		filter_max      = gl.LINEAR,
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

	data := stb.load(file, &width, &height, &nrChannels, 0)

	generate_texture(&texture, width, height, data)
	stb.image_free(data)

	return texture
}
