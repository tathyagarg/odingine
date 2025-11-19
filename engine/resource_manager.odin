package rm

import gl "vendor:OpenGL"

import "core:fmt"
import "core:os"
import "core:strings"

import "rendering/internal"

ResourceManager :: struct {
	shaders:  map[string]Shader,
	textures: map[string]u32,
}

Shader :: struct {
	id: u32,
}

initialize_resource_manager :: proc() -> ResourceManager {
	rm: ResourceManager
	rm.shaders = map[string]Shader{}
	rm.textures = map[string]u32{}
	return rm
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
