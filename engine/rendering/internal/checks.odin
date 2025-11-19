package internal_checks

import gl "vendor:OpenGL"

verify_shader_status :: proc(shader: u32, status_type: u32 = gl.COMPILE_STATUS) -> bool {
	success: i32
	gl.GetShaderiv(shader, status_type, &success)
	if success != 1 {
		info_log: [512]u8
		gl.GetShaderInfoLog(shader, 512, nil, &info_log[0])
	}

	return success == 1
}

verify_program_status :: proc(program: u32, status_type: u32 = gl.LINK_STATUS) -> bool {
	success: i32
	gl.GetProgramiv(program, status_type, &success)
	if success != 1 {
		info_log: [512]u8
		gl.GetProgramInfoLog(program, 512, nil, &info_log[0])
	}

	return success == 1
}
