#+feature dynamic-literals

package scripts

import "base:runtime"
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
	start_callback:       utils.ScriptProc,
	update_callback:      utils.ScriptProc,
}

TopDownMovementScriptInput :: struct {
	speed:                f32,
	limit_diagonal_speed: bool,
	front_texture:        TextureType,
	left_texture:         TextureType,
	right_texture:        TextureType,
	back_texture:         TextureType,
}

DEFUALT_SCRIPTS :: []proc() -> Script{TopDownMovementScript}

TopDownMovementScript :: proc() -> Script {
	arguments := new(TopDownMovementScriptInput)
	arguments.speed = 20.0

	field_count := 6

	argument_descriptors := make([]utils.ArgumentDescriptor, field_count)

	argument_descriptors[0] = utils.ArgumentDescriptor {
		name      = "Speed",
		offset    = offset_of(TopDownMovementScriptInput, speed),
		type_info = typeid_of(f32),
	}

	argument_descriptors[1] = utils.ArgumentDescriptor {
		name      = "Limit Diagonal Speed",
		offset    = offset_of(TopDownMovementScriptInput, limit_diagonal_speed),
		type_info = typeid_of(bool),
		tooltip   = "When disabled, when two movement keys of different axes are pressed (e.g., W and A), the character will move faster diagonally (two velocities add along the diagonal to give a resultant velocity sqrt(2) times the expected). Enabling this option normalizes diagonal movement speed to match single-axis movement speed.",
	}

	argument_descriptors[2] = utils.ArgumentDescriptor {
		name      = "Front Texture",
		offset    = offset_of(TopDownMovementScriptInput, front_texture),
		type_info = typeid_of(TextureType),
	}

	argument_descriptors[3] = utils.ArgumentDescriptor {
		name      = "Left Texture",
		offset    = offset_of(TopDownMovementScriptInput, left_texture),
		type_info = typeid_of(TextureType),
	}

	argument_descriptors[4] = utils.ArgumentDescriptor {
		name      = "Right Texture",
		offset    = offset_of(TopDownMovementScriptInput, right_texture),
		type_info = typeid_of(TextureType),
	}

	argument_descriptors[5] = utils.ArgumentDescriptor {
		name      = "Back Texture",
		offset    = offset_of(TopDownMovementScriptInput, back_texture),
		type_info = typeid_of(TextureType),
	}

	return Script {
		name = "TopDownMovement",
		description = "Handles basic keyboard movement controls.",
		arguments = arguments,
		argument_type = typeid_of(TopDownMovementScriptInput),
		argument_descriptors = argument_descriptors,
		start_callback = proc(
			state: ^utils.SharedContext,
			target: globals.RenderObjectHandle,
			args: rawptr,
		) {},
		update_callback = proc(
			state: ^utils.SharedContext,
			target: globals.RenderObjectHandle,
			args: rawptr,
		) {
			target := (^rendering.RenderObject)(target)
			args := (^TopDownMovementScriptInput)(args)

			key_state := state.key_state

			if key_state[glfw.KEY_W] {
				delta_speed := args.speed

				if args.limit_diagonal_speed && (key_state[glfw.KEY_A] || key_state[glfw.KEY_D]) {
					delta_speed *= 0.7071
				}

				target.position[1] -= delta_speed
				target.texture = utils.texture_at_index(
					&state.manager.texture_manager,
					args.back_texture,
				)
			}
			if key_state[glfw.KEY_S] {
				delta_speed := args.speed
				if args.limit_diagonal_speed && (key_state[glfw.KEY_A] || key_state[glfw.KEY_D]) {
					delta_speed *= 0.7071
				}

				target.position[1] += delta_speed
				target.texture = utils.texture_at_index(
					&state.manager.texture_manager,
					args.front_texture,
				)
			}
			if key_state[glfw.KEY_A] {
				delta_speed := args.speed
				if args.limit_diagonal_speed && (key_state[glfw.KEY_W] || key_state[glfw.KEY_S]) {
					delta_speed *= 0.7071
				}

				target.position[0] -= delta_speed
				target.texture = utils.texture_at_index(
					&state.manager.texture_manager,
					args.left_texture,
				)
			}
			if key_state[glfw.KEY_D] {
				delta_speed := args.speed
				if args.limit_diagonal_speed && (key_state[glfw.KEY_W] || key_state[glfw.KEY_S]) {
					delta_speed *= 0.7071
				}

				target.position[0] += delta_speed
				target.texture = utils.texture_at_index(
					&state.manager.texture_manager,
					args.right_texture,
				)
			}
		},
	}
}

// Flat2DMovementScriptInput :: struct {
// 	speed:         f32,
// 	gravity:       f32,
// 	left_texture:  TextureType,
// 	right_texture: TextureType,
// 	jump_texture:  TextureType,
// 	fall_texture:  TextureType,
// }

// Flat2DMovementScript :: proc() -> Script {
// 	arguments := new(Flat2DMovementScriptInput)
// 	arguments.speed = 15.0
// 	arguments.gravity = 1.0
//
// 	field_count := 5
//
// 	argument_descriptors := make([]utils.ArgumentDescriptor, field_count)
//
// 	argument_descriptors[0] = utils.ArgumentDescriptor {
// 		name      = "Speed",
// 		offset    = offset_of(Flat2DMovementScriptInput, speed),
// 		type_info = typeid_of(f32),
// 	}
//
// 	argument_descriptors[1] = utils.ArgumentDescriptor {
// 		name      = "Gravity",
// 		offset    = offset_of(Flat2DMovementScriptInput, gravity),
// 		type_info = typeid_of(f32),
// 	}
//
// 	argument_descriptors[2] = utils.ArgumentDescriptor {
// 		name      = "Left Texture",
// 		offset    = offset_of(Flat2DMovementScriptInput, left_texture),
// 		type_info = typeid_of(TextureType),
// 	}
//
// 	argument_descriptors[3] = utils.ArgumentDescriptor {
// 		name      = "Right Texture",
// 		offset    = offset_of(Flat2DMovementScriptInput, right_texture),
// 		type_info = typeid_of(TextureType),
// 	}
//
// 	argument_descriptors[4] = utils.ArgumentDescriptor {
// 		name      = "Jump Texture",
// 		offset    = offset_of(Flat2DMovementScriptInput, jump_texture),
// 		type_info = typeid_of(TextureType),
// 	}
//
// 	return Script {
// 		name = "Flat2DMovement",
// 		description = "Handles basic 2D platformer movement controls.",
// 		arguments = arguments,
// 		argument_type = typeid_of(Flat2DMovementScriptInput),
// 		argument_descriptors = argument_descriptors,
// 		key_listeners = map[i32]utils.ScriptProc {
// 			glfw.KEY_A = proc(
// 				state: ^utils.SharedContext,
// 				target: globals.RenderObjectHandle,
// 				args: rawptr,
// 			) {
// 				target := (^rendering.RenderObject)(target)
// 				args := (^Flat2DMovementScriptInput)(args)
//
// 				if target != nil {
// 					target.position[0] -= args.speed
// 					texture := utils.texture_at_index(
// 						&state.manager.texture_manager,
// 						args.left_texture,
// 					)
// 					if texture != nil {
// 						target.texture = texture
// 					}
// 				}
// 			},
// 			glfw.KEY_D = proc(
// 				state: ^utils.SharedContext,
// 				target: globals.RenderObjectHandle,
// 				args: rawptr,
// 			) {
// 				target := (^rendering.RenderObject)(target)
// 				args := (^Flat2DMovementScriptInput)(args)
//
// 				if target != nil {
// 					target.position[0] += args.speed
// 					texture := utils.texture_at_index(
// 						&state.manager.texture_manager,
// 						args.right_texture,
// 					)
// 					if texture != nil {
// 						target.texture = texture
// 					}
// 				}
// 			},
// 			glfw.KEY_SPACE = proc(
// 				state: ^utils.SharedContext,
// 				target: globals.RenderObjectHandle,
// 				args: rawptr,
// 			) {
// 				target := (^rendering.RenderObject)(target)
// 				args := (^Flat2DMovementScriptInput)(args)
//
// 				if target != nil {
// 					target.velocity[1] = 10.0
// 					texture := utils.texture_at_index(
// 						&state.manager.texture_manager,
// 						args.jump_texture,
// 					)
// 					if texture != nil {
// 						target.texture = texture
// 					}
// 				}
// 			},
// 		},
// 	}
// }
//
// MouseMovementScript :: proc() -> Script {
// 	return Script {
// 		name = "MouseMovement",
// 		description = "Handles basic mouse movement controls.",
// 		key_listeners = map[i32]utils.ScriptProc{},
// 	}
// }

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
		start_callback       = original.start_callback,
		update_callback      = original.update_callback,
		// key_listeners         = original.key_listeners,
		// release_key_listeners = original.release_key_listeners,
	}

	return new_script
}
