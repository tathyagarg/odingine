package main

import "core:fmt"

import gl "vendor:OpenGL"
import "vendor:glfw"

import rendering "../engine/rendering"
import rm "../engine/resource_manager"
import "../utils"

WINDOW_WIDTH :: 1200
WINDOW_HEIGHT :: 800

ENVIRONMENT :: utils.Environment.Development

key_callback :: proc "c" (
	window: glfw.WindowHandle,
	key: i32,
	scancode: i32,
	action: i32,
	mods: i32,
) {
	if (ENVIRONMENT == .Development) {
		if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
			glfw.SetWindowShouldClose(window, true)
		}
	}
}

main :: proc() {
	fmt.println("Starting Odin OpenGL Application")

	glfw.Init()
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	fmt.println("Creating window...")

	window := glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin OpenGL Window", nil, nil)
	if window == nil {
		fmt.println("Failed to create GLFW window")
		utils.terminate()
		return
	}

	glfw.MakeContextCurrent(window)
	gl.load_up_to(3, 3, glfw.gl_set_proc_address)
	w, h := glfw.GetFramebufferSize(window)
	gl.Viewport(0, 0, w, h)

	fmt.println("Initializing 2D rendering context...")

	manager := rm.initialize_resource_manager()

	render_context := rendering.initialize_renderer(&manager)
	defer rendering.cleanup_renderer(&render_context)

	fmt.println("Entering main loop...")

	gl.Enable(gl.SCISSOR_TEST)
	defer gl.Disable(gl.SCISSOR_TEST)

	x, y, width, height := rendering.get_scissor_bounds(ENVIRONMENT, w, h)

	glfw.SetKeyCallback(window, key_callback)

	// shader := rm.get_shader(&manager, "BasicTriangleShader")
	// rm.use_shader(&shader)

	for !glfw.WindowShouldClose(window) {
		gl.Scissor(x, y, width, height)

		rendering.render(&render_context)

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

	glfw.DestroyWindow(window)
	glfw.Terminate()
}
