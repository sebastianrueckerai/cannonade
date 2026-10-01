extends RefCounted
## Shared test helper: walls along the border of a rectangle, each piece
## shaped to connect to its neighbours (Catalog.spawn_wall_for).


## Builds the ring around (x, z); `after_each(tile)` is called after every wall.
static func build(player, map, x: int, z: int, after_each := Callable()) -> void:
	build_rect(player, map, x - 1, z - 1, x + 1, z + 1, after_each)


## Walls along the border of the rectangle (x0, z0)-(x1, z1).
static func build_rect(player, map, x0: int, z0: int, x1: int, z1: int, after_each := Callable()) -> void:
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			if x != x0 and x != x1 and z != z0 and z != z1:
				continue
			var up := z < z1 and (x == x0 or x == x1)
			var down := z > z0 and (x == x0 or x == x1)
			var left := x > x0 and (z == z0 or z == z1)
			var right := x < x1 and (z == z0 or z == z1)
			var t = map.tiles[x][z]
			player.build_wall(t, Catalog.spawn_wall_for([up, down, left, right]))
			if after_each.is_valid():
				after_each.call(t)
