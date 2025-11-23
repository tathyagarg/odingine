#+feature dynamic-literals

package scripts

import "../../utils"
import "../../utils/globals"
import "../rendering"
import "core:mem"

import "vendor:glfw"

Script :: struct {
	name:                 cstring,
	description:          cstring,
	arguments:            rawptr,
	argument_type:        typeid,
	argument_descriptors: []utils.ArgumentDescriptor,
	key_listeners:        map[i32]utils.ScriptProc,
}

KeyboardMovementScriptInput :: struct {
	speed: f32,
}

DEFUALT_SCRIPTS :: []proc() -> Script{KeyboardMovementScript, MouseMovementScript}

KeyboardMovementScript :: proc() -> Script {
	arguments := new(KeyboardMovementScriptInput)
	arguments.speed = 20.0

	argument_descriptors := make([]utils.ArgumentDescriptor, 1)
	argument_descriptors[0] = utils.ArgumentDescriptor {
		name      = "Speed",
		offset    = offset_of(KeyboardMovementScriptInput, speed),
		type_info = typeid_of(f32),
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
	// Create a new instance of the argument struct
	new_arguments, err := mem.alloc(size_of(original.argument_type))
	if err != nil {
		panic("Failed to allocate memory for script arguments.")
	}

	// Copy the contents of the original arguments to the new instance
	mem.copy(new_arguments, original.arguments, size_of(original.argument_type))

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
