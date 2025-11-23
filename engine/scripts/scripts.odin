#+feature dynamic-literals

package scripts

import "../../utils"
import "../../utils/globals"
import "../rendering"

import "vendor:glfw"

Script :: struct {
	name:          cstring,
	description:   cstring,
	key_listeners: map[i32]utils.ScriptProc,
}

DEFUALT_SCRIPTS :: []proc() -> Script{KeyboardMovementScript, MouseMovementScript}

KeyboardMovementScript :: proc() -> Script {
	return Script {
		name = "KeyboardMovement",
		description = "Handles basic keyboard movement controls.",
		key_listeners = map[i32]utils.ScriptProc {
			glfw.KEY_W = proc(
				state: ^utils.SharedContext,
				target: globals.RenderObjectHandle,
				action: i32,
			) {
				target := (^rendering.RenderObject)(target)

				if target != nil && (action == glfw.PRESS || action == glfw.REPEAT) {
					target.position[1] -= 5.0
				}
			},
			glfw.KEY_S = proc(
				state: ^utils.SharedContext,
				target: globals.RenderObjectHandle,
				action: i32,
			) {
				target := (^rendering.RenderObject)(target)

				if target != nil && (action == glfw.PRESS || action == glfw.REPEAT) {
					target.position[1] += 5.0
				}
			},
			glfw.KEY_A = proc(
				state: ^utils.SharedContext,
				target: globals.RenderObjectHandle,
				action: i32,
			) {
				target := (^rendering.RenderObject)(target)

				if target != nil && (action == glfw.PRESS || action == glfw.REPEAT) {
					target.position[0] -= 5.0
				}
			},
			glfw.KEY_D = proc(
				state: ^utils.SharedContext,
				target: globals.RenderObjectHandle,
				action: i32,
			) {
				target := (^rendering.RenderObject)(target)

				if target != nil && (action == glfw.PRESS || action == glfw.REPEAT) {
					target.position[0] += 5.0
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
