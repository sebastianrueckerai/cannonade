extends Node
## Terrain on the battlefield (I90-I97, I116): hills and mountains grow as units - one
## organic mass per ridge, both sides within a tenth of each other in different
## arrangements, a two-tile gap between units, hills doming one level a tile and rocks
## climbing sheer toward the player alone, no column hiding the ground behind it from
## either direction, no free ground walled in, the count a knob (--terrain=N), castle
## rings keeping their reach round every feature, every family shattering block by block
## and freeing its ground tile by tile, a family with its break flag off absorbing every
## hit, placement refusing the tiles, hills growing trees that fly with the block they
## stand on, and the AI shooting the rocks that block its own way but never the ones that
## would open the enemy's.
##   godot --headless --fixed-fps 30 res://tests/terrain_test.tscn

const Main = preload("res://scripts/Main.gd")

var main: Node
var game
var map
var me
var enemy
var failures: Array = []
var ran := 0


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)  # headless windows are 64 x 64
	Main.requested_mode = "versus"
	Main.requested_args = {"seed": "4", "no-decorations": "true"}
	main = Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	game = main.game
	map = game.map
	me = game.players[0]
	enemy = game.players[1]
	enemy.dormant = true
	await _versus_board()
	await _ai_board()
	await _tree_board()
	var ok: bool = failures.is_empty() and ran >= 18
	print("TERRAIN TEST PASSED" if ok else "TERRAIN TEST FAILED: %s" % [failures])
	get_tree().quit(0 if ok else 1)


func check(cond: bool, msg: String) -> void:
	ran += 1
	print(("ok: " if cond else "FAIL: ") + msg)
	if not cond:
		failures.append(msg)


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func centre(c) -> Vector2i:
	return map.tile_index_at(c.go.global_position)


## Builds a game in place once frames are flowing: with no decorations the whole map goes
## up inside add_child, so the board is readable the line after (each sweep game is freed
## before a frame passes, so no AI coroutine starts either).
func _start(mode: String, seed := 4, terrain := -1, decorations := false) -> void:
	Main.requested_mode = mode
	Main.requested_args = {"seed": str(seed)} if decorations else {"seed": str(seed), "no-decorations": "true"}
	if terrain >= 0:
		Main.requested_args["terrain"] = str(terrain)
	main = Main.new()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	game = main.game
	map = game.map
	me = game.players[0]
	enemy = game.players[1]


func _blocked(x: int, z: int) -> bool:
	var t = map.tiles[x][z]
	return U.alive(t.structure) and U.comp(t.structure, "Terrain") != null


func _shell_tiles(centre_cell: Vector2i) -> Array:
	var out: Array = []
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var p := Vector2i(centre_cell.x + dx, centre_cell.y + dz)
			if p.x >= 0 and p.y >= 0 and p.x < map.sizeX and p.y < map.sizeZ:
				out.append(p)
	return out


## The encirclement guarantee, written here on its own: from the build ring of the first
## castle, ground no terrain and no water blocks reaches a tile of every other castle's ring.
func _rings_reach() -> bool:
	var centres: Array = []
	for c in map.castles:
		if U.alive(c.go) and not c.is_ruin():
			centres.append(centre(c))
	if centres.size() < 2:
		return true
	var seen := {}
	var queue: Array = []
	for p in _shell_tiles(centres[0]):
		seen[p] = true
		queue.append(p)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + v
			if n.x < 0 or n.y < 0 or n.x >= map.sizeX or n.y >= map.sizeZ or seen.has(n):
				continue
			var t = map.tiles[n.x][n.y]
			if (t.water and not t.river) or _blocked(n.x, n.y):  # a wall bridges a river (I104)
				continue
			seen[n] = true
			queue.append(n)
	for i in range(1, centres.size()):
		var reached := false
		for p in _shell_tiles(centres[i]):
			if seen.has(p):
				reached = true
		if not reached:
			return false
	return true


## Floods a border tile into `seen` unless terrain stands on it (I97: only terrain walls
## ground in; water is crossed, castles and walls are the players' own doing).
func _open_seed(p: Vector2i, seen: Dictionary, queue: Array) -> void:
	if not _blocked(p.x, p.y) and not seen.has(p):
		seen[p] = true
		queue.append(p)


## An edge's identity: both endpoints' positions, order-independent, rounded against
## last-ulp differences between the two expressions that compute a shared lattice point.
func _edge_key(a: Vector3, b: Vector3) -> Array:
	var key := ["%.3f,%.3f,%.3f" % [a.x, a.y, a.z], "%.3f,%.3f,%.3f" % [b.x, b.y, b.z]]
	key.sort()
	return key


## The generated versus board (seed 4, the enemy idle): the layout rules and the damage.
## The board is already up (built deferred in _ready); later boards use _start.
func _versus_board() -> void:
	await frames(3)

	var centres: Array = map.castles.filter(func(c): return U.alive(c.go)).map(func(c): return centre(c))
	check(map.terrain_features.size() > 0, "the versus map grows terrain features (%d)" % [map.terrain_features.size()])
	var broken := 0
	for go in map.terrain_features:
		var terr := U.comp(go, "Terrain")
		for t in terr.tiles:
			if t.structure != go or map.get_mini(t.idxX, t.idxZ) != 255 or t.water:
				broken += 1
			for q in centres:
				if max(absi(t.idxX - q.x), absi(t.idxZ - q.y)) < 3:
					broken += 1
	check(broken == 0,
			"every feature tile is its structure, mini 255, dry, and Chebyshev 3 off every castle centre")

	# I116: one unit is one mass inside its family's span cap, and units never stand flush
	var span_bad := 0
	var feats: Array = []
	for go in map.terrain_features:
		var terr := U.comp(go, "Terrain")
		var cells := {}
		for t in terr.tiles:
			cells[Vector2i(t.idxX, t.idxZ)] = true
		feats.append(cells)
		var lo := Vector2i(map.sizeX, map.sizeZ)
		var hi := Vector2i.ZERO
		for c in cells:
			lo = lo.min(c)
			hi = hi.max(c)
		var span: int = game.ROCK_SPAN if terr.sort == "rock" else game.HILL_SPAN
		if hi.x - lo.x >= span or hi.y - lo.y >= span:
			span_bad += 1
	check(span_bad == 0, "every unit fits its family's span cap (%d oversize)" % [span_bad])
	var gap_bad := 0
	for i in feats.size():
		for j2 in range(i + 1, feats.size()):
			var gap := 99
			for a: Vector2i in feats[i]:
				for b: Vector2i in feats[j2]:
					gap = mini(gap, maxi(absi(a.x - b.x), absi(a.y - b.y)))
			if gap < game.TERRAIN_GAP:
				gap_bad += 1
	check(gap_bad == 0, "units keep a free tile between them (%d pairs too close)" % [gap_bad])

	var mismatch := 0
	var counts := [0, 0]
	for x in map.sizeX:
		for z in map.sizeZ:
			if _blocked(x, z):
				counts[0 if z < map.sizeZ / 2 else 1] += 1
			if _blocked(x, z) != _blocked(x, map.sizeZ - 1 - z):
				mismatch += 1
	check(counts[0] > 0 and counts[1] > 0 and absi(counts[0] - counts[1]) <= 0.1 * maxi(counts[0], counts[1]) + 1 and mismatch > 0,
			"the sides hold roughly the same amount of blocked tiles in different arrangements (%d and %d, %d tiles off the flip)" % [counts[0], counts[1], mismatch])
	check(_rings_reach(), "every castle's build ring reaches every other's round the terrain")

	# a clump's holes stay ground (I93): a horseshoe claimed on open tiles leaves its mouth
	# buildable while its own cells refuse a wall
	var mouth := Vector2i(-1, -1)
	var u_cells: Array = []
	for z in range(6, map.sizeZ - 2):
		for x in range(2, map.sizeX - 3):
			var cells: Array = []
			for dx in range(-2, 3):
				cells.append(Vector2i(x + dx, z - 1))
			cells.append(Vector2i(x - 2, z))
			cells.append(Vector2i(x + 2, z))
			var fits := true
			for c in cells:
				fits = fits and map.tiles[c.x][c.y].is_free() and not map.tiles[c.x][c.y].water
			if fits and map.tiles[x][z].is_free():
				mouth = Vector2i(x, z)
				u_cells = cells
				break
		if mouth.x >= 0:
			break
	var fits_u: bool = mouth.x >= 0
	if fits_u:
		var u_go: Node3D = game._terrain_go("rock", u_cells)
		map.claim_terrain(u_go, u_cells)
		var hole_ok: Node3D = me.place(Catalog.get_def("wall"), mouth.x, mouth.y)
		var on_block: Node3D = me.place(Catalog.get_def("wall"), mouth.x - 2, mouth.y - 1)
		check(hole_ok != null and on_block == null,
				"a wall places in a clump's mouth, never on its cells")
		if hole_ok != null:
			map.tiles[mouth.x][mouth.y].un_build(true)
		U.comp(u_go, "Terrain").die(Vector3.INF, 0.0)
	else:
		check(false, "open ground for the horseshoe exists at the scripted spot")

	var victim = null
	for go in map.terrain_features:
		var terr = U.comp(go, "Terrain")
		if terr == null or not terr.destructible:
			continue
		var tallest := 0
		for t in terr.tiles:
			tallest = maxi(tallest, terr.columns[t])
		if tallest >= 2 and (victim == null or terr.tiles.size() < victim.tiles.size()):
			victim = terr
	check(victim != null, "a destructible feature with a stacked column stands on the map")
	if victim != null:
		var first = victim.tiles[0]
		for t in victim.tiles:
			if victim.columns[t] > victim.columns[first]:
				first = t
		var blocks := 0
		for t in victim.tiles:
			blocks += victim.columns[t]
		check(is_equal_approx(victim.health, 10.0 * blocks),
				"a feature holds 10 health a block (%d blocks, %s hp)" % [blocks, victim.health])
		check(not me.can_place(Catalog.get_def("wall"), first.idxX, first.idxZ)
				and me.place(Catalog.get_def("wall"), first.idxX, first.idxZ) == null,
				"no wall can be placed on a terrain tile")
		var mass: MeshInstance3D = victim.go.get_node_or_null("Mass")
		check(mass != null and mass.mesh != null, "a feature wears one merged drape mesh")
		if mass != null and mass.mesh != null:
			# the blanket's faces must front the outside viewer: Godot culls a face whose cross
			# product (b-a)x(c-a) points at the viewer, so a correct skirt's cross product points
			# into the mass and a correct top's points down (found in play, 2026-10-23)
			var wv: PackedVector3Array = mass.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var east := -1e9
			for t3 in victim.tiles:
				east = maxf(east, t3.go.position.x - victim.go.position.x)
			var skirts := 0
			var wrong := 0
			var tops := 0
			var down := 0
			for i in range(0, wv.size(), 3):
				var wa := wv[i]
				var wb := wv[i + 1]
				var wc := wv[i + 2]
				if wa.y < -0.2 or wb.y < -0.2 or wc.y < -0.2:
					if (wa.x + wb.x + wc.x) / 3.0 > east + 0.4:
						skirts += 1
						if (wb - wa).cross(wc - wa).x >= 0.0:
							wrong += 1
				else:
					tops += 1
					if (wb - wa).cross(wc - wa).y >= 0.0:
						down += 1
			check(skirts > 0 and wrong == 0 and down == 0,
					"the blanket fronts the viewer (%d east skirts, %d culled from outside, %d of %d tops culled from above)" % [skirts, wrong, down, tops])

			# every wall stands on one of the feature's exposed edges: the S/E/N/W neighbour
			# pairing shipped rotated once, walls stood inside the mass and the open sides
			# stayed bare (found in play, 2026-10-23)
			var vcells := {}
			for t3 in victim.tiles:
				vcells[Vector2i(t3.idxX, t3.idxZ)] = true
			var vedges: Array = []
			for c in vcells:
				var vbase: Vector3 = map.tile_position(c.x, c.y) - victim.go.position
				for d in [[Vector2i(1, 0), Vector2(0.5, 0), Vector2(0, 1)], [Vector2i(-1, 0), Vector2(-0.5, 0), Vector2(0, 1)],
						[Vector2i(0, 1), Vector2(0, -0.5), Vector2(1, 0)], [Vector2i(0, -1), Vector2(0, 0.5), Vector2(1, 0)]]:
					if not vcells.has(c + d[0]):
						vedges.append([Vector2(vbase.x, vbase.z) + d[1] - d[2] / 2.0, Vector2(vbase.x, vbase.z) + d[1] + d[2] / 2.0])
			var vwalls := 0
			var voff := 0
			var vbare := 0
			var vhit := []
			for e in vedges:
				vhit.append(false)
			for i in range(0, wv.size(), 3):
				if wv[i].y < -0.2 or wv[i + 1].y < -0.2 or wv[i + 2].y < -0.2:
					vwalls += 1
					var m2 := Vector2((wv[i].x + wv[i + 1].x + wv[i + 2].x) / 3.0, (wv[i].z + wv[i + 1].z + wv[i + 2].z) / 3.0)
					var on_edge := false
					for ei in vedges.size():
						var e: Array = vedges[ei]
						var ab: Vector2 = e[1] - e[0]
						var t2 := clampf((m2 - e[0]).dot(ab) / ab.length_squared(), 0.0, 1.0)
						if (e[0] + ab * t2).distance_to(m2) < 0.15:
							on_edge = true
							vhit[ei] = true
					if not on_edge:
						voff += 1
			for h in vhit:
				if not h:
					vbare += 1
			var vsteps := 3 if victim.sort == "hill" else 2
			check(vwalls == vedges.size() * 2 * vsteps and voff == 0 and vbare == 0,
					"every exposed edge wears its wall strip, %d quads deep (%d walls, %d off, %d of %d edges bare)"
					% [vsteps, vwalls, voff, vbare, vedges.size()])

			# the wall's rim runs through the top's own lattice points, vertex for vertex:
			# the walls once ran chord-straight between the lattice corners while the top rim
			# subdivided, and the higher stories cracked off them (found in play, 2026-10-23)
			var skirt_edges := {}
			var top_counts := {}
			for i in range(0, wv.size(), 3):
				var tri := [wv[i], wv[i + 1], wv[i + 2]]
				var skirted: bool = tri[0].y < -0.2 or tri[1].y < -0.2 or tri[2].y < -0.2
				for e2 in [[tri[0], tri[1]], [tri[1], tri[2]], [tri[2], tri[0]]]:
					var k2 := _edge_key(e2[0], e2[1])
					if skirted:
						skirt_edges[k2] = true
					else:
						top_counts[k2] = top_counts.get(k2, 0) + 1
			var loose := 0
			for k2 in top_counts:
				if top_counts[k2] == 1 and not skirt_edges.has(k2):
					loose += 1
			check(loose == 0,
					"every rim edge of the top is a wall's rim edge, vertex for vertex (%d loose)" % loose)
		var cut: Mesh = mass.mesh if mass != null else null
		var column: int = victim.columns[first]
		for i in column - 1:
			first.damage_building_place(10.0)
		check(map.terrain_features.has(victim.go) and first.structure == victim.go
				and victim.columns[first] == 1,
				"a column steps down block by block without freeing its tile")
		check(mass != null and mass.mesh != null and mass.mesh != cut,
				"a block's fall re-cuts the drape")
		var heaps := 0
		var pieces := 0
		var frozen := 0
		for n in map.go.get_children():
			if n is Crumble:
				heaps += 1
				for b in n.get_children():
					if b is RigidBody3D:
						pieces += 1
			elif n is MeshInstance3D and n.mesh is BoxMesh:
				# the debris once stayed behind as a static cube: crumble refuses a node
				# without art (found in play, 2026-10-23)
				frozen += 1
		check(heaps > 0 and pieces >= 4 and frozen == 0,
				"a shot-out block bursts into flying rubble (%d heaps, %d pieces, %d cubes left standing)"
				% [heaps, pieces, frozen])
		first.damage_building_place(25.0)  # overkill: a shell's leftover damage must stop at the freed tile
		await frames(2)
		check(first.structure == null and first.is_free() and map.get_mini(first.idxX, first.idxZ) == 0
				and map.terrain_features.has(victim.go),
				"the column's last block frees its tile alone, the feature stands")
		check(is_equal_approx(first.groundDamage, 10.0),
				"the freed tile carries the killing shell's scar")
		var vtiles: Array = victim.tiles.duplicate()  # the dying go frees its Terrain with it
		var vgo: Node3D = victim.go
		for t in vtiles:
			for i in victim.columns[t]:
				t.damage_building_place(10.0)
		await frames(2)
		var freed := true
		var scarred := true
		for t in vtiles:
			if t.structure != null or not t.is_free() or map.get_mini(t.idxX, t.idxZ) != 0:
				freed = false
			if t.groundDamage != 10.0:
				scarred = false
		check(not map.terrain_features.has(vgo) and freed,
				"the last column's fall takes the feature with it, every tile freed")
		check(scarred, "each freed tile carries the killing shell's scar")

	# the hole a shell bites crumbles: every corner pooling a wounded cell sags by a bite
	# keyed on its place, deterministic as the roughness, so the re-cut reads as broken
	# ground, not a carved cube (found in play, 2026-10-23)
	var crater = null
	var cc := Vector2i.ZERO
	var cbite := 0.0
	for go in map.terrain_features:
		var terr = U.comp(go, "Terrain")
		if terr == null or terr.sort != "rock":
			continue
		for i in range(1, map.sizeX - 1):
			for j in range(1, map.sizeZ - 1):
				var inner := true
				for c in [Vector2i(i - 1, j - 1), Vector2i(i, j - 1), Vector2i(i - 1, j), Vector2i(i, j)]:
					if terr.columns.get(map.tiles[c.x][c.y], 0) < 1:
						inner = false
				if not inner:
					continue
				var bite: float = absf(terr._noise(Vector2(i, j) + Vector2(terr.go.position.x, terr.go.position.z) + Vector2(97.3, 45.1))) * 0.28
				if bite > cbite:
					cbite = bite
					crater = terr
					cc = Vector2i(i, j)
	check(crater != null, "a rock with an interior corner stands on the map")
	if crater != null:
		var four := [cc + Vector2i(-1, -1), cc + Vector2i(0, -1), cc + Vector2i(-1, 0), cc]
		var top_cell: Vector2i = four[0]
		for c in four:
			if crater.columns[map.tiles[c.x][c.y]] > crater.columns[map.tiles[top_cell.x][top_cell.y]]:
				top_cell = c
		var before: float = crater._corners[cc]
		map.tiles[top_cell.x][top_cell.y].damage_building_place(10.0)
		var tallest_after := 0
		for c in four:
			tallest_after = maxi(tallest_after, crater.columns.get(map.tiles[c.x][c.y], 0))
		check(is_equal_approx(crater._corners[cc], (tallest_after - cbite) * crater.LEVEL)
				and crater._corners[cc] < before - 0.01,
				"the lip of a shot-out block sags: the wounded corner pools %.3f, the bite takes %.3f m"
				% [crater._corners[cc], cbite * crater.LEVEL])

	var flagged := 0
	for go in map.terrain_features:
		if U.comp(go, "Terrain").destructible:
			flagged += 1
	check(flagged == map.terrain_features.size(),
			"every family's break flag ships on (%d of %d features break)" % [flagged, map.terrain_features.size()])
	var mountain = null
	for go in map.terrain_features:
		var terr = U.comp(go, "Terrain")
		if terr != null and terr.tiles.size() > 1:
			mountain = terr
			break
	check(mountain != null, "a multi-tile feature stands on the map")
	if mountain != null:
		mountain.destructible = false  # what a flag-off family ships as
		var stone = mountain.tiles[0]
		for i in 10:
			stone.damage_building_place(30.0)
		var stone_blocks := 0
		for t in mountain.tiles:
			stone_blocks += mountain.columns[t]
		check(map.terrain_features.has(mountain.go) and stone.structure == mountain.go
				and is_equal_approx(mountain.health, 10.0 * stone_blocks),
				"a flag-off family soaks every shell without a scratch")
		mountain.destructible = true
		var before: float = mountain.health
		stone.damage_building_place(10.0)
		check(is_equal_approx(mountain.health, before - 10.0),
				"the same family with its flag on loses one block to one shell")

	main.free()
	await _seed_sweep()


## The layout over more seeds and the four-player flips, each game read and freed before a
## frame passes, so no AI coroutine starts.
func _seed_sweep() -> void:
	var kinds := {"rock": 0, "hill": 0}
	var big := 0
	var solid_big := 0
	var gap_bad := 0
	var span_bad := 0
	var dome_bad := 0
	var far_bad := 0
	var side_bad := 0
	var tall := 0
	var draped := 0
	var fam_max := {}
	var over := 0
	var sfeet := 0
	var steep_feet := 0
	for s in [2] + range(10, 18):  # seed 2: a board the growth leaves one side rich until balanced
		_start("versus", s)
		var mismatch := 0
		var counts := [0, 0]
		for x in map.sizeX:
			for z in map.sizeZ:
				if _blocked(x, z):
					counts[0 if z < map.sizeZ / 2 else 1] += 1
				if _blocked(x, z) != _blocked(x, map.sizeZ - 1 - z):
					mismatch += 1
		for go in map.terrain_features:
			kinds[U.comp(go, "Terrain").sort] += 1
		# I116: a unit is one mass inside its family's span cap, never a filled rectangle, a
		# hill doming one level a tile (rim at one story) and a rock easing one level a tile
		# from its far rim; no two units stand flush against each other.
		var feats: Array = []
		for go in map.terrain_features:
			var terr := U.comp(go, "Terrain")
			var cells := {}
			for t in terr.tiles:
				cells[Vector2i(t.idxX, t.idxZ)] = true
			feats.append(cells)
			var lo := Vector2i(map.sizeX, map.sizeZ)
			var hi := Vector2i.ZERO
			for c in cells:
				lo = lo.min(c)
				hi = hi.max(c)
			if hi.x - lo.x >= 4 or hi.y - lo.y >= 4:
				big += 1
				if cells.size() == (hi.x - lo.x + 1) * (hi.y - lo.y + 1):
					solid_big += 1
			var span: int = game.ROCK_SPAN if terr.sort == "rock" else game.HILL_SPAN
			if hi.x - lo.x >= span or hi.y - lo.y >= span:
				span_bad += 1
			if terr.sort == "hill":
				for c in cells:
					var rim := false
					for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if not cells.has(c + v):
							rim = true
						elif absi(terr.columns[map.tiles[c.x + v.x][c.y + v.y]] - terr.columns[map.tiles[c.x][c.y]]) > 1:
							dome_bad += 1
					if rim and terr.columns[map.tiles[c.x][c.y]] != 1:
						dome_bad += 1
			else:
				var top := {}  # each x-column's far rim, where its north slope starts
				for c in cells:
					top[c.x] = maxi(top.get(c.x, c.y), c.y)
				for c in cells:
					if terr.columns[map.tiles[c.x][c.y]] > 1 + top[c.x] - c.y:
						far_bad += 1
					for d in [Vector2i(1, 0), Vector2i(-1, 0)]:
						var n: Vector2i = c + d
						if n.x < 0 or n.x >= map.sizeX:
							continue
						var n_cols: int = terr.columns[map.tiles[n.x][n.y]] if cells.has(n) else 0
						if absi(terr.columns[map.tiles[c.x][c.y]] - n_cols) > 1:
							side_bad += 1
		for i in feats.size():
			for j2 in range(i + 1, feats.size()):
				var gap := 99
				for a: Vector2i in feats[i]:
					for b: Vector2i in feats[j2]:
						gap = mini(gap, maxi(absi(a.x - b.x), absi(a.y - b.y)))
				if gap < game.TERRAIN_GAP:
					gap_bad += 1
		check(map.terrain_features.size() > 0 and counts[0] > 0 and counts[1] > 0
				and absi(counts[0] - counts[1]) <= 0.1 * maxi(counts[0], counts[1]) + 1 and mismatch > 0 and _rings_reach(),
				"seed %d: terrain grows, the sides near level and different, the rings connected (%d features)" % [s, map.terrain_features.size()])
		# I97: solid shapes and open ground. No free tile is walled in by terrain (a ring
		# would strand the tiles inside it); every column stands on levels that leave the
		# ground behind it visible from the 60-degree play camera: a column hides the centre
		# of the tile k tiles behind it once its height beats that tile's half-tile climb.
		var open_seen := {}
		var open_queue: Array = []
		for x in map.sizeX:
			for z in [0, map.sizeZ - 1]:
				_open_seed(Vector2i(x, z), open_seen, open_queue)
		for z in map.sizeZ:
			for x in [0, map.sizeX - 1]:
				_open_seed(Vector2i(x, z), open_seen, open_queue)
		var head := 0
		while head < open_queue.size():
			var p: Vector2i = open_queue[head]
			head += 1
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = p + v
				if n.x < 0 or n.y < 0 or n.x >= map.sizeX or n.y >= map.sizeZ or open_seen.has(n):
					continue
				if _blocked(n.x, n.y):
					continue
				open_seen[n] = true
				open_queue.append(n)
		var enclosed := 0
		var views := 0
		var rise := tan(deg_to_rad(60.0))
		for x in map.sizeX:
			for z in map.sizeZ:
				var t = map.tiles[x][z]
				if t.structure == null and not t.water and not t.disabled and not open_seen.has(Vector2i(x, z)):
					enclosed += 1
				if t.structure != null or t.water or t.disabled:
					continue
				for z2 in range(z + 1, map.sizeZ):
					var t2 = map.tiles[x][z2]
					var terr2 = U.comp(t2.structure, "Terrain") if U.alive(t2.structure) else null
					if terr2 == null:
						continue
					if terr2.surface_at(t2.idxX, t2.idxZ - 0.5) - t2.go.position.y > (z2 - z - 0.5) * rise:
						views += 1
				for z2 in range(z):
					var t2 = map.tiles[x][z2]
					var terr2 = U.comp(t2.structure, "Terrain") if U.alive(t2.structure) else null
					if terr2 == null:
						continue
					if terr2.surface_at(t2.idxX, t2.idxZ + 0.5) - t2.go.position.y > (z - z2 - 0.5) * rise:
						views += 1
		for go in map.terrain_features:
			var terr3 := U.comp(go, "Terrain")
			var m3: MeshInstance3D = go.get_node_or_null("Mass")
			var hmax := 0
			for t in terr3.tiles:
				if terr3.columns[t] >= 2:
					tall += 1
				hmax = maxi(hmax, terr3.columns[t])
			fam_max[terr3.sort] = maxi(fam_max.get(terr3.sort, 0), hmax)
			if hmax > (4 if terr3.sort == "rock" else 3):  # rocks four stories, hills three
				over += 1
			var top3 := m3.mesh.get_aabb().end.y if m3 != null and m3.mesh != null else -1.0
			if not (top3 > 0.6 and top3 < hmax * 0.75 + 0.3):
				draped += 1
			if terr3.sort == "hill":
				# a hill's south rim rises from the board: the rim column there stands at
				# one story (the backing rule), so the pooled rim corner eases under a
				# third of a level; undomed it sits at the full first story
				var fset := {}
				for t in terr3.tiles:
					fset[Vector2i(t.idxX, t.idxZ)] = true
				for c in terr3._corners:
					if c.y < 1 or fset.has(Vector2i(c.x - 1, c.y - 1)) or fset.has(Vector2i(c.x, c.y - 1)):
						continue
					if not (fset.has(Vector2i(c.x - 1, c.y)) or fset.has(Vector2i(c.x, c.y))):
						continue
					sfeet += 1
					var lim: float = (0.35 if hmax >= 2 else 0.9) * terr3.LEVEL + 0.001
					if terr3._corners[c] > lim:
						steep_feet += 1
		check(enclosed == 0 and views == 0,
				"seed %d: no free tile walled in (%d), no column hides the ground behind it from either direction (%d)" % [s, enclosed, views])
		main.free()
	check(kinds["rock"] > 0 and kinds["hill"] > 0,
			"across the seeds both sorts appear (%d rocks, %d hills)" % [kinds["rock"], kinds["hill"]])
	check(big >= 4 and solid_big == 0,
			"bigger masses appear (%d of five tiles across or more) and none is a filled rectangle (%d solid)" % [big, solid_big])
	check(gap_bad == 0 and span_bad == 0,
			"units keep their gap (%d pairs flush) and their span caps (%d oversize)" % [gap_bad, span_bad])
	check(dome_bad == 0 and far_bad == 0 and side_bad == 0,
			"hills dome one level a tile with a one-story rim (%d breaks), rocks ease one level a tile from their far rim (%d breaks) and on their east and west faces (%d breaks)" % [dome_bad, far_bad, side_bad])
	check(tall >= 100, "terrain rises in stacked levels (%d columns two high or more across the seeds)" % [tall])
	check(draped == 0, "every drape stands inside its levels (%d features out of band)" % [draped])
	check(fam_max.get("rock", 0) == 4 and fam_max.get("hill", 0) == 3 and over == 0,
			"rocks stand up to four stories, hills three (tallest %d and %d, %d over)"
			% [fam_max.get("rock", 0), fam_max.get("hill", 0), over])
	check(steep_feet == 0 and sfeet > 0,
			"hill feet rise from the board: south rim corners ease under a third of a level (%d of %d high)"
			% [steep_feet, sfeet])
	_start("versus", 19, 3)
	check(map.terrain_features.size() == 6,
			"--terrain=3 grows three units a side (%d features)" % [map.terrain_features.size()])
	main.free()
	_start("versus", 19, 0)
	check(map.terrain_features.is_empty(), "--terrain=0 clears the battlefield")
	main.free()
	_start("ai4", 5)
	var quads := [0, 0, 0, 0]
	for x in map.sizeX:
		for z in map.sizeZ:
			if _blocked(x, z):
				quads[(1 if z >= map.sizeZ / 2 else 0) * 2 + (1 if x >= map.sizeX / 2 else 0)] += 1
	check(map.terrain_features.size() > 0 and maxi(maxi(quads[0], quads[1]), maxi(quads[2], quads[3]))
			- mini(mini(quads[0], quads[1]), mini(quads[2], quads[3])) <= 0.1 * maxi(maxi(quads[0], quads[1]), maxi(quads[2], quads[3])) + 1 and _rings_reach(),
			"four players: the quarters hold near the same amount of blocked tiles (%s) and the rings stay connected" % [str(quads)])
	main.free()


## Hills grow trees on the drape and a tree flies with the block it stood on (I116).
func _tree_board() -> void:
	_start("versus", 4, -1, true)
	var hill = null
	var rock = null
	for go in map.terrain_features:
		var terr := U.comp(go, "Terrain")
		if terr.sort == "hill" and hill == null:
			hill = terr
		elif terr.sort == "rock" and rock == null:
			rock = terr
	check(hill != null, "a hill stands on the decorated board")
	check(rock != null, "a rock stands on the decorated board")
	if hill == null or rock == null:
		main.free()
		return
	var treed := 0
	var highest := 0.0
	for t in hill.tiles:
		for d in t.decorations:
			treed += 1
			highest = maxf(highest, d.position.y)
	check(treed > 0, "hills grow trees (%d decorations)" % [treed])
	check(highest > 0.5, "a tree stands above the board's ground on the drape's slope (%.2f m)" % [highest])
	var bare := 0
	for t in rock.tiles:
		bare += t.decorations.size()
	check(bare == 0, "rocks stay bare (%d decorations)" % [bare])
	var block_tile = null
	for t in hill.tiles:
		if not t.decorations.is_empty():
			block_tile = t
			break
	if block_tile != null:
		block_tile.damage_building_place(10.0)
		check(block_tile.decorations.is_empty(), "the tree flies with the block it stood on")
	main.free()


## The AI's terrain tier (I92) on a bare board: a line of rocks across the middle cuts the
## AI from every castle it wants, and the same rocks lose their target once they would
## mainly open the enemy's way.
func _ai_board() -> void:
	_start("ai2")
	me.dormant = true
	enemy.dormant = true
	await frames(3)

	for go in map.terrain_features.duplicate():
		U.comp(go, "Terrain").die(Vector3(0.0, 0.0, 1.0), 0.0)
	for c in map.castles:
		if U.alive(c.go) and c.owner() == null:
			var cc := centre(c)
			for i in 12:
				map.tiles[cc.x][cc.y].damage_building_place(10.0)

	var zline := -1
	for z in range(map.sizeZ / 2 - 4, map.sizeZ / 2 + 4):
		var clear := true
		for x in map.sizeX:
			var t = map.tiles[x][z]
			if U.alive(t.structure) or (t.water and not t.river) or t.disabled or U.alive(t.ship):
				clear = false
				break
		if clear:
			zline = z
			break
	check(zline >= 0, "a clear row crosses the middle of the bare board")
	if zline < 0:
		main.free()
		return

	var cells: Array = []
	for x in map.sizeX:
		cells.append(Vector2i(x, zline))
	var wall: Node3D = game._terrain_go("rock", cells)
	map.claim_terrain(wall, cells)
	check(not _rings_reach(), "a full-width rock line really cuts the rings (the detector sees it)")
	var gun_spot := Vector2i(-1, -1)
	for x in range(2, 14):
		for z in range(2, 14):
			if map.tiles[x][z].is_free():
				gun_spot = Vector2i(x, z)
				break
		if gun_spot.x >= 0:
			break
	me.build_building(map.tiles[gun_spot.x][gun_spot.y], Catalog.spawn("cannon"))
	me.refresh_active_cannons()

	# a neutral castle south of the line: clearing helps only the AI, so the rocks are shot
	var south := _place_neutral(zline + 6, map.sizeZ - 4)
	check(south.x >= 0, "a neutral castle stands south of the line")
	var targets: Array = me._terrain_targets(enemy)
	var on_line := true
	for t in targets:
		if t.idxZ != zline:
			on_line = false
	check(not targets.is_empty() and on_line,
			"the AI targets the rocks that cut it off from every castle it wants (%d tiles)" % [targets.size()])

	# the neutral north of the line instead: clearing would open the enemy's way, not the AI's
	for i in 12:
		map.tiles[south.x][south.y].damage_building_place(10.0)
	var north := _place_neutral(3, zline - 3)
	check(north.x >= 0, "a neutral castle stands north of the line")
	targets = me._terrain_targets(enemy)
	check(targets.is_empty(),
			"rocks that would mainly open the enemy's way are left standing (%d tiles)" % [targets.size()])

	# and with no castle left that the line does not already hide, clearing would only open
	# the enemy's way to the AI's castle: the rocks stand for that reason alone
	for i in 12:
		map.tiles[north.x][north.y].damage_building_place(10.0)
	targets = me._terrain_targets(enemy)
	check(targets.is_empty(),
			"rocks that cut both sides off equally are left standing too (%d tiles)" % [targets.size()])
	main.free()


## Places a neutral castle on a free 3x3 in z rows [lo, hi), x spread over the map.
## Returns the centre, or (-1, -1) when no spot is free.
func _place_neutral(lo: int, hi: int) -> Vector2i:
	for z in range(lo, hi):
		for x in [map.sizeX / 4, 3 * map.sizeX / 4, map.sizeX / 2 - 8, map.sizeX / 2 + 5, 3, map.sizeX - 6]:
			if x < 1 or x + 2 >= map.sizeX - 1 or z < 1 or z + 2 >= map.sizeZ - 1:
				continue
			if map.place_neutral(Catalog.get_def("castle"), x, z) != null:
				return Vector2i(x + 1, z + 1)
	return Vector2i(-1, -1)
