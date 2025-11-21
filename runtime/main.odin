package main

import "core:fmt"

import imgui "../third_party/imgui"
import imgui_glfw "../third_party/imgui/imgui_impl_glfw"
import imgui_opengl3 "../third_party/imgui/imgui_impl_opengl3"
import gl "vendor:OpenGL"
import "vendor:glfw"

import atl "../engine/atlas"
import gui "../engine/gui"
import rendering "../engine/rendering"
import sprites "../engine/rendering/sprite"
import rm "../engine/resource_manager"
import "../utils"

WINDOW_WIDTH :: 1200
WINDOW_HEIGHT :: 800

ENVIRONMENT :: utils.Environment.Development

TILESET_TEXTURE_PATH :: "resources/atlases/01_grass"

BASE_SPRITE_VERTEX_SHADER :: #load("../resources/shaders/02_sprite/sprite.vert")
BASE_SPRITE_FRAGMENT_SHADER :: #load("../resources/shaders/02_sprite/sprite.frag")

TILE_SCALE :: 2

key_callback :: proc "c" (
	window: glfw.WindowHandle,
	key: i32,
	scancode: i32,
	action: i32,
	mods: i32,
) {
	when (ENVIRONMENT == .Development) {
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

	projection := utils.orthographic_projection_matrix(
		0.0,
		f32(WINDOW_WIDTH),
		f32(WINDOW_HEIGHT),
		0.0,
		-1.0,
		1.0,
	)

	render_context := rendering.initialize_renderer(
		&manager,
		string(BASE_SPRITE_VERTEX_SHADER),
		string(BASE_SPRITE_FRAGMENT_SHADER),
		&projection,
	)
	defer rendering.cleanup_renderer(&render_context)

	res := atl.parse(TILESET_TEXTURE_PATH)
	if res == nil {
		fmt.println("Failed to initialize texture atlas")
		utils.terminate()
		return
	}
	atlas := res.?

	rm.load_atlas(&manager, atlas)

	// rm.load_texture(&manager, "grass_1", TILESET_TEXTURE_PATH + "/tileset_grass.png")

	// append(
	// 	&render_context.objects,
	// 	rendering.RenderObject {
	// 		position = {f32(100), f32(100)},
	// 		size = {f32(64), f32(64)},
	// 		rotation = f32(0),
	// 		texture = rm.get_texture(&manager, "grass_1"),
	// 	},
	// )

	sprite_shader := rm.get_shader(&manager, "sprite")
	for tileset_id, i in atlas.presets[0].tile_ids {
		texture: rm.Texture
		for name, t in atlas.tiles {
			if t.id == tileset_id {
				fmt.println("Loading texture:", name)
				texture = rm.get_texture(&manager, name)
				fmt.println("Texture loaded:", texture)
				break
			}
		}

		append(
			&render_context.objects,
			rendering.RenderObject {
				sprite = sprites.initialize_sprite(&manager, &sprite_shader),
				position = {
					f32(TILE_SCALE * (i % atlas.presets[0].size[0]) * atlas.header.sprite_size[0]),
					f32(TILE_SCALE * (i / atlas.presets[0].size[0]) * atlas.header.sprite_size[1]),
				},
				size = {
					f32(TILE_SCALE * atlas.header.sprite_size[0]),
					f32(TILE_SCALE * atlas.header.sprite_size[1]),
				},
				rotation = f32(0),
				texture = texture,
			},
		)
	}

	fmt.println(render_context.objects)

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

		when (ENVIRONMENT == .Development) {
			gl.Viewport(0, 0, w, h)

			imgui_glfw.NewFrame()
			imgui_opengl3.NewFrame()
			imgui.NewFrame()

			gui.show_gui(WINDOW_WIDTH, WINDOW_HEIGHT)

			imgui.Render()

			imgui_opengl3.RenderDrawData(imgui.GetDrawData())
		}

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

	glfw.DestroyWindow(window)
	glfw.Terminate()
}
