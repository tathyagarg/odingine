package scripts

import "../../utils"
import "../../utils/globals"
import "../rendering"

import "vendor:glfw"


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
