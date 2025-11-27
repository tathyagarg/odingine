package rendering

import "core:fmt"
import "core:sort"
import "core:strings"

import gl "vendor:OpenGL"

import "../../utils/globals"
import atl "../atlas"
import render_sprite "../rendering/sprite"
import rm "../resource_manager"

import imgui "../../third_party/imgui"

TextureType :: globals.TextureType

RenderObjectKind :: enum {
	None,
	AtlasPreset,
}

RenderObject :: struct {
	name:     string,
	sprite:   render_sprite.Sprite,
	texture:  ^rm.Texture,
	position: [2]f32,
	velocity: [2]f32,
	size:     [2]f32,
	rotation: f32,
	scripts:  [dynamic]globals.ScriptHandle,
	kind:     RenderObjectKind,
}

RenderLayer :: struct {
	name:    cstring,
	objects: [dynamic]RenderObject,
	z_layer: i32,
}

Background :: union {
	imgui.Vec4,
	^RenderObject,
}

RendererContext :: struct {
	manager:    ^rm.ResourceManager,
	layers:     [dynamic]RenderLayer,
	background: Background,
	// objects: [dynamic]RenderObject,
}

initialize_renderer :: proc(
	manager: ^rm.ResourceManager,
	sprite_vertex_shader: string,
	sprite_fragment_shader: string,
	projection: ^matrix[4, 4]f32,
) -> RendererContext {
	rm.load_shader(manager, "sprite", sprite_vertex_shader, sprite_fragment_shader)

	shader := rm.get_shader(manager, "sprite")
	rm.use_shader(&shader)
	rm.set_matrix4("projection", projection, &shader)
	rm.set_integer("image", 0, &shader)

	layers: [dynamic]RenderLayer = {}
	return RendererContext {
		manager = manager,
		layers = layers,
		background = imgui.Vec4{0.2, 0.3, 0.4, 1.0},
	}
}

render :: proc(ctx: ^RendererContext) {
	gl.Clear(gl.COLOR_BUFFER_BIT)
	switch bg in ctx.background {
	case imgui.Vec4:
		gl.ClearColor(bg.x, bg.y, bg.z, bg.w)
	case ^RenderObject:
		render_sprite.draw_sprite(
			ctx.manager,
			&bg.sprite,
			bg.texture,
			[2]f32{0.0, 0.0},
			[2]f32{f32(globals.WINDOW_WIDTH), f32(globals.WINDOW_HEIGHT)},
			0.0,
		)
	}

	for &layer in ctx.layers {
		for &object in layer.objects {
			if object.texture == nil {
				continue
			}

			render_sprite.draw_sprite(
				ctx.manager,
				&object.sprite,
				object.texture,
				object.position,
				object.size,
				-object.rotation * globals.DEGREES_TO_RADIANS,
			)
		}
	}
}

cleanup_renderer :: proc(ctx: ^RendererContext) {}

get_scissor_bounds :: proc(env: globals.Environment, width: i32, height: i32) -> [4]i32 {
	if env == .Development {
		w := f32(width)
		h := f32(height)

		return [4]i32 {
			i32((w - (w * globals.WINDOW_TO_SCREEN_SCALE)) / 2),
			i32(h - (h * globals.WINDOW_TO_SCREEN_SCALE)),
			i32(w * globals.WINDOW_TO_SCREEN_SCALE),
			i32(h * globals.WINDOW_TO_SCREEN_SCALE),
		}
	} else {
		return [4]i32{0, 0, width, height}
	}
}

add_layer :: proc(ctx: ^RendererContext, name: string, z_layer: i32) {
	layer_name := strings.unsafe_string_to_cstring(name)
	new_layer := RenderLayer {
		name    = layer_name,
		objects = [dynamic]RenderObject{},
		z_layer = z_layer,
	}
	append(&ctx.layers, new_layer)

	sort.quick_sort_proc(ctx.layers[:], proc(a: RenderLayer, b: RenderLayer) -> int {
		return int(a.z_layer - b.z_layer)
	})

	fmt.println("Added layer '", name, "' with z-layer ", z_layer)
	fmt.println("Current layers:")
	fmt.println(ctx.layers)
}

render_atlas_preset :: proc(
	ctx: ^RendererContext,
	manager: ^rm.ResourceManager,
	atlas: ^atl.Atlas,
	preset: string,
	layer: u32,
	offset: [2]f32,
) {
	preset_data, ok := atlas.presets.presets[preset]
	if !ok {
		fmt.println("Preset '", preset, "' not found in atlas.")
		return
	}

	sprite_shader := rm.get_shader(manager, "sprite")

	fmt.println("Rendering preset '", preset, "' at offset ", offset)

	append(
		&ctx.layers[layer].objects,
		RenderObject {
			name = preset,
			sprite = render_sprite.initialize_preset(manager, &sprite_shader, &preset_data, atlas),
			position = offset,
			size = {
				f32(atlas.header.sprite_size[0]) * globals.TILE_SCALE * f32(preset_data.size[0]),
				f32(atlas.header.sprite_size[1]) * globals.TILE_SCALE * f32(preset_data.size[1]),
			},
			rotation = f32(0),
			texture = rm.get_texture(manager, atlas.header.name),
			scripts = [dynamic]globals.ScriptHandle{},
			kind = .AtlasPreset,
		},
	)
}

render_object_kind_to_string :: proc(kind: RenderObjectKind) -> string {
	switch kind {
	case .None:
		return "None"
	case .AtlasPreset:
		return "Atlas Preset"
	}
	return "Unknown"
}
