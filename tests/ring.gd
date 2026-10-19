extends RefCounted
## Shared test helper: a full-tile wall block on every border tile of a rectangle.


## Builds the ring around (x, z); `after_each(tile)` is called after every wall.
static func build(player, map, x: int, z: int, after_each := Callable()) -> void:
	build_rect(player, map, x - 1, z - 1, x + 1, z + 1, after_each)


## Walls along the border of the rectangle (x0, z0)-(x1, z1).
static func build_rect(player, map, x0: int, z0: int, x1: int, z1: int, after_each := Callable()) -> void:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			if x != x0 and x != x1 and z != z0 and z != z1:
				continue
			var t = map.tiles[x][z]
			player.build_wall(t, Catalog.spawn("wall"))
			if after_each.is_valid():
				after_each.call(t)
