package atlas

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:sort"
import "core:strconv"
import "core:strings"

Tile :: struct {
	position: [2]int,
	id:       int,
}

Preset :: struct {
	size:     [2]int,
	tile_ids: []int,
}

PresetManager :: struct {
	keys:    [dynamic]string,
	presets: map[string]Preset,
}

Header :: struct {
	name:         string,
	filename:     cstring,
	sprite_count: int,
	sprite_size:  [2]int,
	atlas_size:   [2]int,
}

Atlas :: struct {
	source:  cstring,
	header:  Header,
	tiles:   map[string]Tile,
	presets: PresetManager,
}

add_preset :: proc(manager: ^PresetManager, name: string, preset: Preset) {
	if manager == nil {
		fmt.println("Cannot add preset to a nil manager")
		return
	}

	if _, exists := manager.presets[name]; !exists {
		append(&manager.keys, name)
	}

	manager.presets[name] = preset
}

load_file :: proc(path: string) -> (string, string, bool) {
	target: string = ""
	fullpath: string = ""

	if os.is_dir(path) {
		handle, open_err := os.open(path)
		if open_err != nil {
			fmt.println("Error opening directory: ", open_err)
			return "", "", false
		}

		files, read_err := os.read_dir(handle, 1024)
		if read_err != nil {
			fmt.println("Error reading directory: ", read_err)
			return "", "", false
		}

		for file in files {
			if strings.ends_with(file.name, ".atlas") {
				target = file.name
				break
			}
		}

		if target == "" {
			fmt.println("No atlas file found in directory: ", path)
			return "", "", false
		}

		fullpath = filepath.join([]string{path, target})
	} else {
		target = path
		fullpath = path
	}

	data, read_err := os.read_entire_file_from_filename_or_err(fullpath)
	if read_err != nil {
		fmt.println("Error reading atlas file: ", read_err)
		return "", "", false
	}

	return string(data), fullpath, true
}

parse_header :: proc(path: string, data: string) -> Maybe(Header) {
	lines := strings.split(data, "\n")
	header := Header{}

	if len(lines) < 5 {
		fmt.println("Invalid header format")
		return nil
	}

	if !strings.starts_with(lines[0], "header:") {
		// How did we get here?
		fmt.println("Invalid header start")
		return nil
	}

	for line in lines[1:] {
		parts := strings.split(line, ":")
		if len(parts) != 2 {
			fmt.println("Invalid header line: ", line)
			return nil
		}

		key := strings.trim(parts[0], " ")
		value := strings.trim(parts[1], " ")

		switch key {
		case "name":
			header.name = value
		case "src":
			header.filename = strings.clone_to_cstring(value)
		case "count":
			count, ok := strconv.parse_int(value)
			if !ok {
				fmt.println("Invalid sprite_count value: ", value)
				return nil
			}
			header.sprite_count = count
		case "sprite_size":
			size_parts := strings.split(value, " ")
			if len(size_parts) != 2 {
				fmt.println("Invalid sprite_size value: ", value)
				return nil
			}
			width, ok1 := strconv.parse_int(strings.trim(size_parts[0], " "))
			height, ok2 := strconv.parse_int(strings.trim(size_parts[1], " "))
			if !ok1 || !ok2 {
				fmt.println("Invalid sprite_size dimensions: ", value, ok1, ok2)
				return nil
			}
			header.sprite_size = [2]int{width, height}
		case "atlas_size":
			size_parts := strings.split(value, " ")
			if len(size_parts) != 2 {
				fmt.println("Invalid atlas_size value: ", value)
				return nil
			}
			width, ok1 := strconv.parse_int(strings.trim(size_parts[0], " "))
			height, ok2 := strconv.parse_int(strings.trim(size_parts[1], " "))
			if !ok1 || !ok2 {
				fmt.println("Invalid atlas_size dimensions: ", value, ok1, ok2)
				return nil
			}
			header.atlas_size = [2]int{width, height}
		}
	}

	if header.filename == nil ||
	   header.sprite_count == 0 ||
	   header.sprite_size[0] == 0 ||
	   header.sprite_size[1] == 0 {
		fmt.println("Incomplete header information")
		return nil
	}

	return header
}

parse_tiles_position :: proc(line: string) -> Maybe([2]int) {
	pos_parts := strings.split(strings.trim(strings.trim_prefix(line, "pos:"), " "), " ")
	if len(pos_parts) != 2 {
		fmt.println("Invalid tile position: ", line)
		return nil
	}
	x, ok1 := strconv.parse_int(strings.trim(pos_parts[0], " "))
	y, ok2 := strconv.parse_int(strings.trim(pos_parts[1], " "))
	if !ok1 || !ok2 {
		fmt.println("Invalid tile position values: ", line)
		return nil
	}
	return [2]int{x, y}
}

parse_tiles_id :: proc(line: string) -> Maybe(int) {
	id_str := strings.trim(strings.trim_prefix(line, "id:"), " ")
	id, ok := strconv.parse_int(id_str)
	if !ok {
		fmt.println("Invalid tile id: ", line)
		return nil
	}
	return id
}

parse_tiles :: proc(data: string, header: Header) -> Maybe(map[string]Tile) {
	lines := strings.split(data, "\n")
	tiles := map[string]Tile{}
	tiles_array := [dynamic]Tile{}

	if len(lines) < 2 {
		fmt.println("Invalid tiles format")
		return nil
	}

	if !strings.starts_with(lines[0], "tiles:") {
		// How did we get here?
		fmt.println("Invalid tiles start")
		return nil
	}

	for i := 1; i < len(lines); i += 1 {
		line := lines[i]
		name := strings.trim(line, " :")

		parsed_pos, parsed_id := false, false
		tile := Tile {
			position = [2]int{0, 0},
			id       = 0,
		}

		if i + 1 < len(lines) {
			next_line := strings.trim(lines[i + 1], " ")
			if strings.starts_with(next_line, "pos:") {
				pos := parse_tiles_position(next_line)
				if pos == nil {
					return nil
				}
				tile.position = pos.?
				parsed_pos = true

				i += 1
			} else if strings.starts_with(next_line, "id:") {
				id := parse_tiles_id(next_line)
				if id == nil {
					return nil
				}

				tile.id = id.?
				parsed_id = true

				i += 1
			}
		}

		if i + 1 < len(lines) {
			next_line := strings.trim(lines[i + 1], " ")
			if strings.starts_with(next_line, "id:") {
				id := parse_tiles_id(next_line)
				if id == nil {
					return nil
				}

				tile.id = id.?
				parsed_id = true

				i += 1
			} else if strings.starts_with(next_line, "pos:") {
				pos := parse_tiles_position(next_line)
				if pos == nil {
					return nil
				}
				tile.position = pos.?
				parsed_pos = true

				i += 1
			}
		}

		if !parsed_pos {
			previous_tile := tiles_array[len(tiles_array) - 1]
			if (previous_tile.position[0] / header.sprite_size[0]) + 1 >= header.atlas_size[0] {
				tile.position = [2]int{0, previous_tile.position[1] + header.sprite_size[1]}
			} else {
				tile.position = [2]int {
					previous_tile.position[0] + header.sprite_size[0],
					previous_tile.position[1],
				}
			}
		}

		if !parsed_id {
			if len(tiles_array) == 0 {
				tile.id = 0
			} else {
				tile.id = tiles_array[len(tiles_array) - 1].id + 1
			}
		}

		tiles[name] = tile
		append(&tiles_array, tile)
	}

	return tiles
}

parse_presets :: proc(data: string) -> Maybe(map[string]Preset) {
	lines := strings.split(data, "\n")
	presets := map[string]Preset{}

	if len(lines) < 2 {
		fmt.println("Invalid presets format")
		return nil
	}

	if !strings.starts_with(lines[0], "presets:") {
		// How did we get here?
		fmt.println("Invalid presets start")
		return nil
	}

	i := 1
	for i < len(lines) {
		name := strings.trim(lines[i], " :")

		preset := Preset {
			size     = [2]int{0, 0},
			tile_ids = []int{},
		}

		i += 1
		for i < len(lines) {
			next_line := strings.trim(lines[i], " ")
			if strings.starts_with(next_line, "size:") {
				size_parts := strings.split(
					strings.trim(strings.trim_prefix(next_line, "size:"), " "),
					" ",
				)
				if len(size_parts) != 2 {
					fmt.println("Invalid preset size: ", next_line)
					return nil
				}
				width, ok1 := strconv.parse_int(strings.trim(size_parts[0], " "))
				height, ok2 := strconv.parse_int(strings.trim(size_parts[1], " "))
				if !ok1 || !ok2 {
					fmt.println("Invalid preset size values: ", next_line)
					return nil
				}
				preset.size = [2]int{width, height}
				preset.tile_ids = make([]int, width * height)
			} else if strings.starts_with(next_line, "data:") {
				for row := 0; row < preset.size[1]; row += 1 {
					i += 1
					if i >= len(lines) {
						fmt.println("Unexpected end of preset data")
						return nil
					}

					data_line := strings.trim(lines[i], " ")
					tile_id_strs := strings.split(data_line, " ")
					if len(tile_id_strs) != preset.size[0] {
						fmt.println("Invalid number of tile ids in preset data line: ", data_line)
						return nil
					}

					for id_str, col in tile_id_strs {
						id, ok := strconv.parse_int(strings.trim(id_str, " "))
						if !ok {
							fmt.println("Invalid preset tile id: ", id_str)
							return nil
						}

						preset.tile_ids[row * preset.size[0] + col] = id
					}
				}
			} else {
				break
			}
			i += 1
		}

		if preset.size[0] != 0 && preset.size[1] != 0 {
			presets[name] = preset
		}
	}

	return presets
}

parse :: proc(path: string) -> Maybe(Atlas) {
	data, full_path, ok := load_file(path)
	if !ok {
		return nil
	}

	parts := strings.split(data, "\n\n")
	if len(parts) < 2 {
		fmt.println("Invalid atlas file format")
		return nil
	}

	atlas := Atlas {
		source = strings.clone_to_cstring(full_path),
	}

	for part in parts {
		if strings.starts_with(part, "header") {
			header := parse_header(path, part)
			if header == nil {
				return nil
			}

			atlas.header = header.?
		} else if strings.starts_with(part, "tiles") {
			tiles := parse_tiles(part, atlas.header)
			if tiles == nil {
				return nil
			}

			if len(tiles.?) != atlas.header.sprite_count {
				fmt.println("Warning: Parsed tile count does not match header sprite_count")
			}

			atlas.tiles = tiles.?
		} else if strings.starts_with(part, "presets") {
			presets := parse_presets(part)
			if presets == nil {
				return nil
			}

			for name, preset in presets.? {
				add_preset(&atlas.presets, name, preset)
			}
		}
	}

	if atlas.header.filename == nil || len(atlas.tiles) == 0 {
		fmt.println("Incomplete atlas data")
		return nil
	}

	return atlas
}

save_atlas_to_path :: proc(atlas: ^Atlas, path: string) {
	if atlas == nil {
		fmt.println("Cannot save a nil atlas")
		return
	}

	atlas.source = strings.clone_to_cstring(path)
	save_atlas(atlas)
}

save_atlas :: proc(atlas: ^Atlas) {
	if atlas == nil {
		fmt.println("Cannot save a nil atlas")
		return
	}

	fmt.println("Saving atlas to: ", string(atlas.source))
	file, err := os.open(string(atlas.source), os.O_RDWR | os.O_CREATE)
	if err != nil {
		fmt.println("Error creating atlas file: ", err)
		return
	}

	content := ""

	content = strings.concatenate(
		{
			content,
			fmt.aprintf(
				"header:\n  name: %s\n  src: %s\n  count: %d\n  sprite_size: %d %d\n  atlas_size: %d %d\n\n",
				atlas.header.name,
				filepath.base(string(atlas.header.filename)),
				atlas.header.sprite_count,
				atlas.header.sprite_size[0],
				atlas.header.sprite_size[1],
				atlas.header.atlas_size[0],
				atlas.header.atlas_size[1],
			),
		},
	)

	content = strings.concatenate({content, "tiles:\n"})

	tiles, err2 := slice.map_entries(atlas.tiles)
	if err2 != nil {
		fmt.println("Error retrieving tile values: ", err2)
		return
	}

	sort.quick_sort_proc(
		tiles,
		proc(a: slice.Map_Entry(string, Tile), b: slice.Map_Entry(string, Tile)) -> int {
			return sort.compare_ints(a.value.id, b.value.id)
		},
	)

	for entry in tiles {
		name, tile := entry.key, entry.value

		content = strings.concatenate(
			{
				content,
				fmt.aprintf(
					"  %s:\n    pos: %d %d\n    id: %d\n",
					name,
					tile.position[0],
					tile.position[1],
					tile.id,
				),
			},
		)
	}

	content = strings.concatenate({content, "\npresets:\n"})

	for name, preset in atlas.presets.presets {
		content = strings.concatenate(
			{
				content,
				fmt.aprintf(
					"  %s:\n  size: %d %d\n    data:\n",
					name,
					preset.size[0],
					preset.size[1],
				),
			},
		)
		for row := 0; row < preset.size[1]; row += 1 {
			line := "        "
			for col := 0; col < preset.size[0]; col += 1 {
				line = strings.concatenate(
					{line, fmt.aprintf("%d ", preset.tile_ids[row * preset.size[0] + col])},
				)
			}
			content = strings.concatenate({content, strings.concatenate({line, "\n"})})
		}
	}

	_, write_err := os.write(file, transmute([]u8)content)
}
