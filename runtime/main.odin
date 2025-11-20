package main

import "core:fmt"

import imgui "../third_party/imgui"
import imgui_glfw "../third_party/imgui/imgui_impl_glfw"
import imgui_opengl3 "../third_party/imgui/imgui_impl_opengl3"
import gl "vendor:OpenGL"
import "vendor:glfw"

import gui "../engine/gui"
import rendering "../engine/rendering"
import rm "../engine/resource_manager"
import "../utils"

WINDOW_WIDTH :: 1200
WINDOW_HEIGHT :: 800

ENVIRONMENT :: utils.Environment.Development

TILESET_TEXTURE_PATH :: "resources/textures/tileset_grass.png"

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

	fmt.println("Initializing 2D rendering context...")

	manager := rm.initialize_resource_manager()

	render_context := rendering.initialize_renderer(&manager)
	defer rendering.cleanup_renderer(&render_context)

	tileset_mapping: map[string]int = make(map[string]int)

	// this was macro'd I didn't write it by hand
	tileset_mapping["grass_1"] = 0
	tileset_mapping["grass_2"] = 1
	tileset_mapping["grass_3"] = 2
	tileset_mapping["grass_4"] = 3
	tileset_mapping["flower_grass_1"] = 4
	tileset_mapping["flower_grass_2"] = 5
	tileset_mapping["flower_grass_3"] = 6
	tileset_mapping["flower_grass_4"] = 7
	tileset_mapping["grass_5"] = 8
	tileset_mapping["grass_6"] = 9
	tileset_mapping["grass_7"] = 10
	tileset_mapping["grass_8"] = 11
	tileset_mapping["flower_grass_5"] = 12
	tileset_mapping["flower_grass_6"] = 13
	tileset_mapping["flower_grass_7"] = 14
	tileset_mapping["flower_grass_8"] = 15
	tileset_mapping["grass_9"] = 16
	tileset_mapping["grass_10"] = 17
	tileset_mapping["grass_11"] = 18
	tileset_mapping["grass_12"] = 19
	tileset_mapping["flower_grass_9"] = 20
	tileset_mapping["flower_grass_10"] = 21
	tileset_mapping["flower_grass_11"] = 22
	tileset_mapping["flower_grass_12"] = 23
	tileset_mapping["grass_13"] = 24
	tileset_mapping["grass_14"] = 25
	tileset_mapping["grass_15"] = 26
	tileset_mapping["grass_16"] = 27
	tileset_mapping["flower_grass_13"] = 28
	tileset_mapping["flower_grass_14"] = 29
	tileset_mapping["flower_grass_15"] = 30
	tileset_mapping["flower_grass_16"] = 31
	tileset_mapping["stone_full_1_good"] = 32
	tileset_mapping["stone_full_2_good"] = 33
	tileset_mapping["stone_left_1_good"] = 34
	tileset_mapping["stone_right_1_good"] = 35
	tileset_mapping["stone_bottom_1_good"] = 36
	tileset_mapping["stone_bottom_2_decent"] = 37
	tileset_mapping["stone_bottom_3_bad"] = 38
	tileset_mapping["stone_bottom_4_horrible"] = 39
	tileset_mapping["stone_full_3_decent"] = 40
	tileset_mapping["stone_full_4_decent"] = 41
	tileset_mapping["stone_left_2_decent"] = 42
	tileset_mapping["stone_right_2_decent"] = 43
	tileset_mapping["stone_top_1_good"] = 44
	tileset_mapping["stone_top_2_decent"] = 45
	tileset_mapping["stone_top_3_bad"] = 46
	tileset_mapping["stone_top_4_horrible"] = 47
	tileset_mapping["stone_full_5_bad"] = 48
	tileset_mapping["stone_full_6_bad"] = 49
	tileset_mapping["stone_left_3_bad"] = 50
	tileset_mapping["stone_right_3_bad"] = 51
	tileset_mapping["stone_tl"] = 52
	tileset_mapping["stone_tr"] = 53
	tileset_mapping["stone_bl"] = 54
	tileset_mapping["stone_br"] = 55
	tileset_mapping["stone_full_7_horrible"] = 56
	tileset_mapping["stone_full_8_horrible"] = 57
	tileset_mapping["stone_left_4_horrible"] = 58
	tileset_mapping["stone_right_4_horrible"] = 59
	tileset_mapping["stone_full_7_horrible_flip"] = 60
	tileset_mapping["stone_full_8_horrible_flip"] = 61

	tileset: []string = make([]string, len(tileset_mapping))
	for name, index in tileset_mapping {
		tileset[index] = name
	}

	rm.load_atlas(&manager, tileset, TILESET_TEXTURE_PATH, 32, 32, 62)

	imgui.CreateContext()
	imgui.StyleColorsDark()

	imgui_glfw.InitForOpenGL(window, true)
	defer imgui_glfw.Shutdown()

	imgui_opengl3.Init("#version 330")
	defer imgui_opengl3.Shutdown()

	fmt.println("Entering main loop...")

	gl.Enable(gl.SCISSOR_TEST)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	x, y, width, height := rendering.get_scissor_bounds(ENVIRONMENT, w, h)

	glfw.SetKeyCallback(window, key_callback)

	imgui.SetNextWindowPos(
		imgui.Vec2{f32(0), f32(0)},
		imgui.Cond.Always,
		imgui.Vec2{f32(0), f32(0)},
	)

	for !glfw.WindowShouldClose(window) {
		gl.Viewport(x, y, width, height)
		gl.Scissor(x, y, width, height)
		rendering.render(&render_context)

		gl.Viewport(0, 0, w, h)

		imgui_glfw.NewFrame()
		imgui_opengl3.NewFrame()
		imgui.NewFrame()

		gui.show_gui(WINDOW_WIDTH, WINDOW_HEIGHT)

		imgui.Render()

		imgui_opengl3.RenderDrawData(imgui.GetDrawData())

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

	glfw.DestroyWindow(window)
	glfw.Terminate()
}
