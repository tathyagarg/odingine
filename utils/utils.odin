package utils

import "core:fmt"
import "core:os"

import "vendor:glfw"

Environment :: enum {
	Development,
	Production,
}

terminate :: proc(message: string = "Terminating application due to an error.") {
	fmt.println(message)
	glfw.Terminate()
	os.exit(1)
}
