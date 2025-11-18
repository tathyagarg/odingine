package utils

import "core:fmt"
import "core:os"

import "vendor:glfw"

terminate :: proc(message: string = "Terminating application due to an error.") {
	fmt.println(message)
	glfw.Terminate()
	os.exit(1)
}
