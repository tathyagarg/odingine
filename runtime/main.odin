package main

import "base:runtime"
import "core:fmt"
import "core:strings"

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
import "../engine/scripts"
import "../utils"
import "../utils/globals"

RenderObject :: rendering.RenderObject
RendererContext :: rendering.RendererContext

ENVIRONMENT :: globals.Environment.Development
DEBUG :: true

TILESET_TEXTURE_PATH :: "resources/atlases/01_grass"

BASE_SPRITE_VERTEX_SHADER :: #load("../resources/shaders/02_sprite/sprite.vert")
BASE_SPRITE_FRAGMENT_SHADER :: #load("../resources/shaders/02_sprite/sprite.frag")

BASE_LINE_VERTEX_SHADER :: #load("../resources/shaders/03_line/line.vert")
BASE_LINE_FRAGMENT_SHADER :: #load("../resources/shaders/03_line/line.frag")

save_atlas :: proc(state: ^utils.SharedContext, args: ..any) -> utils.ErrorMessage {
	atlases := state.manager.atlas_manager.atlases

	for name, atlas_ptr in atlases {
		atl.save_atlas(atlas_ptr)
		rm.load_atlas(state.manager, atlas_ptr)
	}

	for &layer in (^RendererContext)(state.render_context).layers {
		for &object in layer.objects {
			if object.texture == nil {
				continue
			}
			object.texture = rm.get_texture(state.manager, object.texture.name)
		}
	}

	return nil
}

load_atlas :: proc(state: ^utils.SharedContext, args: ..any) -> utils.ErrorMessage {
	filepath := state.add_atlas.filepath

	if len(filepath) == 0 {
		fmt.println("Atlas filepath and name cannot be empty.")
		return .EmptyNameOrTextureSource
	}

	res := atl.parse(string(filepath))
	if res == nil {
		fmt.println("Failed to load texture atlas from ", filepath)
		return .FailedToLoadAtlas
	}

	atlas := res.?

	rm.load_atlas(state.manager, &atlas)

	state.add_atlas.filepath = utils.empty_cstring(256)

	return nil
}

add_object :: proc(state: ^utils.SharedContext, args: ..any) -> utils.ErrorMessage {
	name := state.add_object.name
	texture_id := i32(state.add_object.texture)
	position := state.add_object.position

	if len(name) == 0 {
		fmt.println("Object name and texture source cannot be empty.")
		return .EmptyNameOrTextureSource
	}

	texture := rm.get_texture(state.manager, state.manager.texture_manager.keys[texture_id])
	sprite_shader := rm.get_shader(state.manager, "sprite")

	new_object := rendering.RenderObject {
		name     = string(name),
		sprite   = sprites.initialize_sprite(state.manager, &sprite_shader),
		position = position,
		size     = [2]f32{f32(texture.width), f32(texture.height)},
		rotation = f32(0),
		texture  = texture,
	}

	append(
		&(^RendererContext)(state.render_context).layers[state.add_object.layer].objects,
		new_object,
	)
	return nil
}

delete_object :: proc(state: ^utils.SharedContext, args: ..any) -> utils.ErrorMessage {
	if state.focused_object == nil {
		return nil
	}

	ctx := (^RendererContext)(state.render_context)
	for &layer in ctx.layers {
		for i in 0 ..< len(layer.objects) {
			if globals.RenderObjectHandle(&layer.objects[i]) == state.focused_object {
				ordered_remove(&layer.objects, i)
				state.focused_object = nil
				return nil
			}
		}
	}

	return nil
}


load_texture :: proc(state: ^utils.SharedContext, args: ..any) -> utils.ErrorMessage {
	name := state.add_texture.name
	texture_source := state.add_texture.source

	if len(name) == 0 || len(texture_source) == 0 {
		fmt.println("Texture name and source cannot be empty.")
		return .EmptyNameOrTextureSource
	}

	res := rm.load_texture(state.manager, string(name), string(texture_source), true)
	if res == nil {
		fmt.println("Failed to load texture from ", texture_source)
		return .FailedToLoadTexture
	}

	return nil
}

load_texture_preview :: proc(state: ^utils.SharedContext, args: ..any) -> utils.ErrorMessage {
	name := state.add_texture.name
	texture_source := state.add_texture.source

	if len(name) == 0 || len(texture_source) == 0 {
		fmt.println("Texture name and source cannot be empty.")
		return .EmptyNameOrTextureSource
	}

	res := rm.load_texture_without_assign(
		state.manager,
		string(name),
		string(texture_source),
		true,
	)
	if res == nil {
		fmt.println("Failed to load texture from ", texture_source)
		return .FailedToLoadTexture
	}

	state.manager.preview_texture = res

	return nil
}

unload_texture_preview :: proc(state: ^utils.SharedContext, args: ..any) -> utils.ErrorMessage {
	state.manager.preview_texture = nil

	return nil
}

render_atlas_preset :: proc(state: ^utils.SharedContext, args: ..any) -> utils.ErrorMessage {
	atlas_index := state.add_preset.atlas_name
	atlas_name := state.manager.atlas_manager.keys[atlas_index]
	atlas := state.manager.atlas_manager.atlases[atlas_name]

	preset_index := state.add_preset.preset_name
	preset_name := atlas.presets.keys[preset_index]

	layer := state.add_preset.layer_index

	offset := state.add_preset.offset

	rendering.render_atlas_preset(
		(^RendererContext)(state.render_context),
		state.manager,
		atlas,
		string(preset_name),
		u32(layer),
		offset,
	)

	return nil
}

make_texture_permanent_if_preview :: proc(
	state: ^utils.SharedContext,
	args: ..any,
) -> utils.ErrorMessage {
	if state.manager.preview_texture != nil {
		tex_name := state.manager.preview_texture.name
		if tex_name == string(state.add_texture.name) {
			state.manager.preview_texture = nil
			return nil
		}
	}

	return nil
}

key_callback :: proc "c" (
	window: glfw.WindowHandle,
	key: i32,
	scancode: i32,
	action: i32,
	mods: i32,
) {
	context = runtime.default_context()
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

	if (state.game_focused && ENVIRONMENT == .Development) || (ENVIRONMENT == .Production) {
		if action == glfw.PRESS {
			state.key_state[key] = true
		} else if action == glfw.RELEASE {
			state.key_state[key] = false
		}
	}
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, button: i32, action: i32, mods: i32) {
	imgui_glfw.MouseButtonCallback(window, button, action, mods)

	state := (^utils.SharedContext)(glfw.GetWindowUserPointer(window))

	context = runtime.default_context()
	if action == glfw.PRESS {
		when (ENVIRONMENT == .Development) {
			if (!state.game_focused) {
				// This position will be in window coordinates
				raw_x, raw_y := glfw.GetCursorPos(window)

				scissor := rendering.get_scissor_bounds(
					ENVIRONMENT,
					state.window_size[0],
					state.window_size[1],
				)

				x_off, y_off, width, height := scissor[0], scissor[1], scissor[2], scissor[3]

				x := (2 * raw_x - f64(x_off)) / 2 / globals.WINDOW_TO_SCREEN_SCALE
				y := raw_y / globals.WINDOW_TO_SCREEN_SCALE

				if x < 0 ||
				   x > f64(width) / 2 / globals.WINDOW_TO_SCREEN_SCALE ||
				   y < 0 ||
				   y > f64(height) * globals.WINDOW_TO_SCREEN_SCALE {
					return
				}

				ctx := (^RendererContext)(state.render_context)

				layer_count := len(ctx.layers)

				for i in 0 ..< layer_count {
					layer := &ctx.layers[layer_count - 1 - i]

					for &object in layer.objects {
						if object.texture == nil {
							continue
						}

						fmt.println("Click at x:", x, " y:", y)
						fmt.println(
							"Checking object ",
							object.name,
							" at position ",
							object.position,
							" with size ",
							object.size,
						)

						if x >= f64(object.position[0]) &&
						   x <= f64(object.position[0] + object.size[0]) &&
						   y >= f64(object.position[1]) &&
						   y <= f64(object.position[1] + object.size[1]) {

							state.focused_object = globals.RenderObjectHandle(&object)
							return
						}
					}
				}

				state.focused_object = nil
			}
		}
	}
}

main :: proc() {
	using globals

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
		manager,
		string(BASE_SPRITE_VERTEX_SHADER),
		string(BASE_SPRITE_FRAGMENT_SHADER),
		&projection,
	)

	rm.load_shader(
		manager,
		"line",
		string(BASE_LINE_VERTEX_SHADER),
		string(BASE_LINE_FRAGMENT_SHADER),
	)

	defer rendering.cleanup_renderer(&render_context)

	rendering.add_layer(&render_context, "background", 0)
	rendering.add_layer(&render_context, "foreground", 1)

	state := utils.default_shared_context()
	state.window_size = [2]i32{w, h}
	state.manager = manager
	state.render_context = RendererContextHandle(&render_context)

	loaded_scripts := [dynamic]scripts.Script{}
	for script_proc in scripts.DEFUALT_SCRIPTS {
		script := script_proc()
		fmt.println("Loaded script: ", (scripts.Script)(script).name)
		if (scripts.Script)(script).name == "TopDownMovement" {
			fmt.println(
				"Arguments: ",
				((^scripts.TopDownMovementScriptInput)((scripts.Script)(script).arguments))^,
			)
		}
		append(&loaded_scripts, script)
	}

	state.script_manager.scripts = make([]ScriptHandle, len(loaded_scripts))
	for i in 0 ..< len(loaded_scripts) {
		state.script_manager.scripts[i] = globals.ScriptHandle(&loaded_scripts[i])
	}

	when DEBUG {
		sprite_shader := rm.get_shader(manager, "sprite")
		_res := rm.load_texture(manager, "bg", "resources/textures/background.png")

		render_context.background = &rendering.RenderObject {
			sprite = sprites.initialize_sprite(manager, &sprite_shader),
			position = [2]f32{0.0, 0.0},
			size = [2]f32{f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)},
			rotation = 0.0,
			texture = rm.get_texture(manager, "bg"),
		}

		atlas := atl.parse(TILESET_TEXTURE_PATH).?

		fmt.println("Loaded atlas: ", atlas)

		rm.load_atlas(manager, &atlas)

		rendering.render_atlas_preset(
			&render_context,
			manager,
			&atlas,
			"showcase_1",
			0,
			[2]f32{0.0, 0.0},
		)

		// front := rm.load_texture(manager, "front", "resources/textures/character/front.png")
		// left := rm.load_texture(manager, "left", "resources/textures/character/left.png")
		// right := rm.load_texture(manager, "right", "resources/textures/character/right.png")
		// back := rm.load_texture(manager, "back", "resources/textures/character/back.png")

		// player := rendering.RenderObject {
		// 	name     = "player",
		// 	sprite   = sprites.initialize_sprite(manager, &sprite_shader),
		// 	position = [2]f32{100.0, 100.0},
		// 	size     = [2]f32{32.0, 32.0},
		// 	rotation = 0.0,
		// 	texture  = front,
		// }

		// append(&render_context.layers[1].objects, player)
	}


	state.event_handlers["save_atlas"] = save_atlas
	state.event_handlers["load_atlas"] = load_atlas
	state.event_handlers["add_object"] = add_object
	state.event_handlers["delete_object"] = delete_object
	state.event_handlers["load_texture"] = load_texture
	state.event_handlers["load_texture_preview"] = load_texture_preview
	state.event_handlers["unload_texture_preview"] = unload_texture_preview
	state.event_handlers["make_texture_permanent_if_preview"] = make_texture_permanent_if_preview
	state.event_handlers["render_atlas_preset"] = render_atlas_preset

	glfw.SetWindowUserPointer(window, &state)

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

	scissor := rendering.get_scissor_bounds(ENVIRONMENT, w, h)
	x, y, width, height := scissor[0], scissor[1], scissor[2], scissor[3]

	glfw.SetKeyCallback(window, key_callback)
	glfw.SetMouseButtonCallback(window, mouse_callback)

	grid_vao, grid_vbo: u32
	grid_verts, grid_vert_count := utils.make_grid(50, 32 * TILE_SCALE)

	fmt.println("Grid vert count: ", grid_vert_count, " verts: ", grid_verts)

	gl.GenVertexArrays(1, &grid_vao)
	gl.GenBuffers(1, &grid_vbo)

	gl.BindVertexArray(grid_vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, grid_vbo)

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(grid_verts) * size_of(f32),
		raw_data(grid_verts),
		gl.STATIC_DRAW,
	)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	gl.BindVertexArray(0)

	imgui.SetNextWindowPos(
		imgui.Vec2{f32(0), f32(0)},
		imgui.Cond.Always,
		imgui.Vec2{f32(0), f32(0)},
	)

	for !glfw.WindowShouldClose(window) {
		gl.Viewport(x, y, width, height)
		gl.Scissor(x, y, width, height)

		rendering.render(&render_context)

		if (state.game_focused && ENVIRONMENT == .Development) || (ENVIRONMENT == .Production) {
			for reg_script in state.script_manager.registered_scripts {
				script := (^scripts.Script)(reg_script.script)
				script.update_callback(&state, reg_script.target, script.arguments)
			}
		}

		if (state.editing_preset) {
			shader := rm.get_shader(manager, "line")
			rm.use_shader(&shader)

			rm.set_matrix4("projection", &projection, &shader)

			gl.BindVertexArray(grid_vao)
			gl.DrawArrays(gl.LINES, 0, i32(grid_vert_count))
			gl.BindVertexArray(0)
		}

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
