#+feature dynamic-literals

package scripts

import "base:runtime"
import "core:fmt"
import "core:reflect"

import "../../utils"
import "../../utils/globals"
import "../rendering"

import "core:mem"

import "vendor:glfw"

TextureType :: globals.TextureType

Script :: struct {
	name:                 cstring,
	description:          cstring,
	arguments:            rawptr,
	argument_type:        typeid,
	argument_descriptors: []utils.ArgumentDescriptor,
	key_listeners:        map[i32]utils.ScriptProc,
}

KeyboardMovementScriptInput :: struct {
	speed:         f32,
	front_texture: TextureType,
	left_texture:  TextureType,
	right_texture: TextureType,
	back_texture:  TextureType,
}

DEFUALT_SCRIPTS :: []proc() -> Script{KeyboardMovementScript, MouseMovementScript}

KeyboardMovementScript :: proc() -> Script {
	arguments := new(KeyboardMovementScriptInput)
	arguments.speed = 20.0
	// arguments.front_sprite_path = strings.unsafe_string_to_cstring(string(make([]u8, 64)[:0]))
	// arguments.left_sprite_path = strings.unsafe_string_to_cstring(string(make([]u8, 64)[:0]))
	// arguments.right_sprite_path = strings.unsafe_string_to_cstring(string(make([]u8, 64)[:0]))
	// arguments.back_sprite_path = strings.unsafe_string_to_cstring(string(make([]u8, 64)[:0]))

	field_count := 5

	argument_descriptors := make([]utils.ArgumentDescriptor, field_count)

	argument_descriptors[0] = utils.ArgumentDescriptor {
		name      = "Speed",
		offset    = offset_of(KeyboardMovementScriptInput, speed),
		type_info = typeid_of(f32),
	}

	argument_descriptors[1] = utils.ArgumentDescriptor {
		name      = "Front Texture",
		offset    = offset_of(KeyboardMovementScriptInput, front_texture),
		type_info = typeid_of(TextureType),
	}

	argument_descriptors[2] = utils.ArgumentDescriptor {
		name      = "Left Texture",
		offset    = offset_of(KeyboardMovementScriptInput, left_texture),
		type_info = typeid_of(TextureType),
	}

	argument_descriptors[3] = utils.ArgumentDescriptor {
		name      = "Right Texture",
		offset    = offset_of(KeyboardMovementScriptInput, right_texture),
		type_info = typeid_of(TextureType),
	}

	argument_descriptors[4] = utils.ArgumentDescriptor {
		name      = "Back Texture",
		offset    = offset_of(KeyboardMovementScriptInput, back_texture),
		type_info = typeid_of(TextureType),
	}

	return Script {
		name = "KeyboardMovement",
		description = "Handles basic keyboard movement controls.",
		arguments = arguments,
		argument_type = typeid_of(KeyboardMovementScriptInput),
		argument_descriptors = argument_descriptors,
		key_listeners = map[i32]utils.ScriptProc {
			glfw.KEY_W = proc(
				state: ^utils.SharedContext,
				target: globals.RenderObjectHandle,
				action: i32,
				args: rawptr,
			) {
				target := (^rendering.RenderObject)(target)
				args := (^KeyboardMovementScriptInput)(args)

				if target != nil && (action == glfw.PRESS || action == glfw.REPEAT) {
					target.position[1] -= args.speed
					texture := utils.texture_at_index(
						&state.manager.texture_manager,
						args.back_texture,
					)
					if texture != nil {
						target.texture = texture
					}
				}
			},
			glfw.KEY_S = proc(
				state: ^utils.SharedContext,
				target: globals.RenderObjectHandle,
				action: i32,
				args: rawptr,
			) {
				target := (^rendering.RenderObject)(target)
				args := (^KeyboardMovementScriptInput)(args)

				if target != nil && (action == glfw.PRESS || action == glfw.REPEAT) {
					target.position[1] += args.speed
					texture := utils.texture_at_index(
						&state.manager.texture_manager,
						args.front_texture,
					)
					if texture != nil {
						target.texture = texture
					}
				}
			},
			glfw.KEY_A = proc(
				state: ^utils.SharedContext,
				target: globals.RenderObjectHandle,
				action: i32,
				args: rawptr,
			) {
				target := (^rendering.RenderObject)(target)
				args := (^KeyboardMovementScriptInput)(args)

				if target != nil && (action == glfw.PRESS || action == glfw.REPEAT) {
					target.position[0] -= args.speed
					texture := utils.texture_at_index(
						&state.manager.texture_manager,
						args.left_texture,
					)
					if texture != nil {
						target.texture = texture
					}
				}
			},
			glfw.KEY_D = proc(
				state: ^utils.SharedContext,
				target: globals.RenderObjectHandle,
				action: i32,
				args: rawptr,
			) {
				target := (^rendering.RenderObject)(target)
				args := (^KeyboardMovementScriptInput)(args)

				if target != nil && (action == glfw.PRESS || action == glfw.REPEAT) {
					target.position[0] += args.speed
					texture := utils.texture_at_index(
						&state.manager.texture_manager,
						args.right_texture,
					)
					if texture != nil {
						target.texture = texture
					}
				}
			},
		},
	}
}

MouseMovementScript :: proc() -> Script {
	return Script {
		name = "MouseMovement",
		description = "Handles basic mouse movement controls.",
		key_listeners = map[i32]utils.ScriptProc{},
	}
}

clone_script :: proc(original: ^Script) -> ^Script {
	size := reflect.size_of_typeid(original.argument_type)
	align := reflect.align_of_typeid(original.argument_type)

	// Create a new instance of the argument struct
	new_arguments, err := mem.alloc(size, align)
	if err != nil {
		panic("Failed to allocate memory for script arguments.")
	}

	mem.copy(new_arguments, original.arguments, size)

	// Create a new Script instance with copied data
	new_script := new(Script)
	new_script^ = Script {
		name                 = original.name,
		description          = original.description,
		arguments            = new_arguments,
		argument_type        = original.argument_type,
		argument_descriptors = original.argument_descriptors,
		key_listeners        = original.key_listeners,
	}

	return new_script
}
