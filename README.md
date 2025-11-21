# Odingine

![Time stat](https://hackatime-badge.hackclub.com/U082L0UTJ66/odingine)

2D Game Engine written in Odin using OpenGL and GLFW

## .atlas Specification

- The `.atlas` file format is used to define texture atlases for use in the Odingine game engine. A texture atlas is a single image file that contains multiple smaller images (tiles) packed together. This allows for more efficient rendering by reducing the number of texture bindings required during rendering.

- The `.atlas` file is split into sections. After the end of each section, a newline is required.

### File Structure
Each section of the `.atlas` file is defined by a header followed by a series of key-value pairs. The file is structured as follows:

#### Header (`header`)
The header must specify the texture image file name (with `.png` extension) with respect to the location of the `.atlas` file.

```
src: texture.png
```

It must also specify the number of tiles contained in the atlas.

```
count: 3
```

And the size of a single tile in pixels.

```
tile_size: 64 64
```

Full header example:

```
header:
  src: texture.png
  count: 3
  tile_size: 64 64
```

#### Tile Definitions (`tiles`)
Following the header, each tile is defined in a block that starts with the tile name, followed by its position in the atlas (x, y) in pixels. If unspecified, the tile's position defaults to the previous tile's position plus the tile size in the x-direction. If the first tile's position is unspecified, it defaults to `(0, 0)`.

```
hero_idle:
    pos: 0 0
    id: 0

enemy_walk:
    pos: 64 0
    id: 1
```


If the `id` field is not specified for a tile, it defaults to 1 plus the previous tile's id. If the first tile's id is unspecified, it defaults to `0`.

Full tile definitions example:

```
tiles:
  hero_idle:
      pos: 0 0
      id: 0

  enemy_walk:
      pos: 64 0
      id: 1

  coin_spin:
      pos: 128 0
      id: 2
```

#### Presets (`presets`)
The `.atlas` file can also include preset definitions that define a configuration of tiles, and may be used to draw levels.
The preset block starts with the preset name, followed by the size of the level in tiles (width height), and then the tile data itself, where each number corresponds to a tile id.

```
level_1:
    size: 5 5
    data:
        0 0 1 1 0
        0 2 2 2 0
        1 2 3 2 1
        0 2 2 2 0
        0 0 1 1 0
```
