package main

import "base:runtime"
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
import "../utils/globals"

WINDOW_WIDTH :: 1600
WINDOW_HEIGHT :: 900

ENVIRONMENT :: globals.Environment.Development

TILESET_TEXTURE_PATH :: "resources/atlases/01_grass"

BASE_SPRITE_VERTEX_SHADER :: #load("../resources/shaders/02_sprite/sprite.vert")
BASE_SPRITE_FRAGMENT_SHADER :: #load("../resources/shaders/02_sprite/sprite.frag")

TILE_SCALE :: 5.6

key_callback :: proc "c" (
	window: glfw.WindowHandle,
	key: i32,
	scancode: i32,
	action: i32,
	mods: i32,
) {
	imgui_glfw.KeyCallback(window, key, scancode, action, mods)

	state := (^utils.SharedContext)(glfw.GetWindowUserPointer(window))
	when (ENVIRONMENT == .Development) {
		if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
			if state.game_focused {
				state.game_focused = false
			} else {
				glfw.SetWindowShouldClose(window, true)
			}
		}
	}

	if state.game_focused {
		if action == glfw.PRESS {
			context = runtime.default_context()
			fmt.println("Key pressed: ", key)
		}
	}
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, button: i32, action: i32, mods: i32) {
	imgui_glfw.MouseButtonCallback(window, button, action, mods)

	state := (^utils.SharedContext)(glfw.GetWindowUserPointer(window))

	context = runtime.default_context()
	if action == glfw.PRESS {
		// This position will be in window coordinates
		raw_x, raw_y := glfw.GetCursorPos(window)

		x_off, y_off, width, height := rendering.get_scissor_bounds(
			ENVIRONMENT,
			state.window_size[0],
			state.window_size[1],
		)


		x := (2 * raw_x - f64(x_off)) / 2 / globals.WINDOW_TO_SCREEN_SCALE
		y := raw_y / globals.WINDOW_TO_SCREEN_SCALE

		for &layer in state.render_context.layers {
			for &object in layer.objects {
				if object.texture == nil {
					continue
				}

				if x >= f64(object.position[0]) &&
				   x <= f64(object.position[0] + object.size[0]) &&
				   y >= f64(object.position[1]) &&
				   y <= f64(object.position[1] + object.size[1]) {
					fmt.println(
						"Clicked on object '",
						object.texture.name,
						"' in layer '",
						layer.name,
						"'",
					)
				}
			}
		}
	}
}

main :: proc() {
	glfw.Init()
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		"Odingine" if (ENVIRONMENT == .Development) else "game",
		nil,
		nil,
	)
	if window == nil {
		fmt.println("Failed to create GLFW window")
		utils.terminate()
		return
	}

	glfw.MakeContextCurrent(window)
	gl.load_up_to(3, 3, glfw.gl_set_proc_address)
	w, h := glfw.GetFramebufferSize(window)
	fmt.println("Framebuffer size: ", w, "x", h)

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

	rendering.add_layer(&render_context, "default", 0)
	rendering.add_layer(&render_context, "background", 1)
	rendering.add_layer(&render_context, "foreground", 2)

	state := utils.default_shared_context()
	state.window_size = [2]i32{w, h}
	state.manager = &manager
	state.render_context = &render_context

	state.event_handlers["save_atlas"] = proc(
		state: ^utils.SharedContext,
		args: ..any,
	) -> utils.ErrorMessage {
		for name, atlas_ptr in state.atlases {
			atl.save_atlas(state.atlases["main"])
			rm.update_textures_from_atlas(state.manager, state.atlases["main"])
		}

		for &layer in state.render_context.layers {
			for &object in layer.objects {
				if object.texture.name == "" {
					continue
				}
				object.texture = rm.get_texture(state.manager, object.texture.name)
			}
		}

		return nil
	}

	state.event_handlers["load_atlas"] = proc(
		state: ^utils.SharedContext,
		args: ..any,
	) -> utils.ErrorMessage {
		filepath := state.add_atlas.filepath
		name := state.add_atlas.name

		fmt.println("Loading atlas from ", filepath, " with name ", name)

		if len(filepath) == 0 || len(name) == 0 {
			fmt.println("Atlas filepath and name cannot be empty.")
			return .EmptyNameOrTextureSource
		}

		res := atl.parse(string(filepath))
		if res == nil {
			fmt.println("Failed to load texture atlas from ", filepath)
			return .FailedToLoadAtlas
		}
		atlas := res.?
		rm.load_atlas(state.manager, atlas)
		state.atlases[string(name)] = &atlas

		return nil
	}

	state.event_handlers["add_object"] = proc(
		state: ^utils.SharedContext,
		args: ..any,
	) -> utils.ErrorMessage {
		name := state.add_object.name
		texture_source := state.add_object.texture_source
		position := state.add_object.position

		if len(name) == 0 || len(texture_source) == 0 {
			fmt.println("Object name and texture source cannot be empty.")
			return .EmptyNameOrTextureSource
		}

		texture := rm.load_texture(state.manager, string(name), string(texture_source), true, true)
		sprite_shader := rm.get_shader(state.manager, "sprite")

		new_object := rendering.RenderObject {
			sprite   = sprites.initialize_sprite(state.manager, &sprite_shader),
			position = position,
			size     = [2]f32{f32(texture.width), f32(texture.height)},
			rotation = f32(0),
			texture  = texture,
		}

		append(&state.render_context.layers[state.add_object.layer].objects, new_object)
		return nil
	}

	glfw.SetWindowUserPointer(window, &state)


	res := atl.parse(TILESET_TEXTURE_PATH)
	if res == nil {
		fmt.println("Failed to initialize texture atlas")
		utils.terminate()
		return
	}
	atlas := res.?

	rm.load_atlas(&manager, atlas)

	sprite_shader := rm.get_shader(&manager, "sprite")

	for tileset_id, i in atlas.presets["showcase_1"].tile_ids {
		texture_name := ""
		for name, t in atlas.tiles {
			if t.id == tileset_id {
				texture_name = name
				break
			}
		}

		append(
			&render_context.layers[0].objects,
			rendering.RenderObject {
				sprite = sprites.initialize_sprite(&manager, &sprite_shader),
				position = {
					TILE_SCALE *
					f32((i % atlas.presets["showcase_1"].size[0])) *
					f32(atlas.header.sprite_size[0]),
					TILE_SCALE *
					f32((i / atlas.presets["showcase_1"].size[0])) *
					f32(atlas.header.sprite_size[1]),
				},
				size = {
					TILE_SCALE * f32(atlas.header.sprite_size[0]),
					TILE_SCALE * f32(atlas.header.sprite_size[1]),
				},
				rotation = f32(0),
				texture = rm.get_texture(&manager, texture_name),
			},
		)
	}

	state.atlases["main"] = &atlas

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
	glfw.SetMouseButtonCallback(window, mouse_callback)

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

			gui.show_gui(WINDOW_WIDTH, WINDOW_HEIGHT, window)

			imgui.Render()

			imgui_opengl3.RenderDrawData(imgui.GetDrawData())
		}

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}

	glfw.DestroyWindow(window)
	glfw.Terminate()
}
