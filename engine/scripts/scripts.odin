#+feature dynamic-literals

package scripts

import "../../utils"
import "../../utils/globals"
import "../rendering"

import "vendor:glfw"

Script :: struct {
	name:          cstring,
	description:   cstring,
	arguments:     rawptr,
	argument_type: typeid,
	key_listeners: map[i32]utils.ScriptProc,
}

KeyboardMovementScriptInput :: struct {
	speed: f32,
}

DEFUALT_SCRIPTS :: []proc() -> Script{KeyboardMovementScript, MouseMovementScript}

KeyboardMovementScript :: proc() -> Script {
	arguments := new(KeyboardMovementScriptInput)
	arguments.speed = 20.0

	return Script {
		name = "KeyboardMovement",
		description = "Handles basic keyboard movement controls.",
		arguments = arguments,
		argument_type = typeid_of(KeyboardMovementScriptInput),
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
