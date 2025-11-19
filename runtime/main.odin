package main

import "core:fmt"

import gl "vendor:OpenGL"
import "vendor:glfw"

import rendering "../engine/rendering"
import "../utils"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

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

	render_context := rendering.initialize_render2d()
	defer rendering.cleanup_render2d(&render_context)

	fmt.println("Entering main loop...")

	for !glfw.WindowShouldClose(window) {
		gl.ClearColor(0.2, 0.3, 0.3, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		rendering.render2d(&render_context)

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

	glfw.DestroyWindow(window)
	glfw.Terminate()
}
