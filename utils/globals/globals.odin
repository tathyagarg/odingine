package globals

WINDOW_TO_SCREEN_SCALE :: 2.0 / 3.0
DEGREES_TO_RADIANS :: 3.14159265 / 180.0

WINDOW_WIDTH :: 1600
WINDOW_HEIGHT :: 900

TILE_SCALE :: 5

RenderObjectHandle :: distinct rawptr
RendererContextHandle :: distinct rawptr
ScriptHandle :: distinct rawptr

Environment :: enum {
	Development,
	Production,
}

TextureType :: distinct i32
