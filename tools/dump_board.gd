extends Node
## Prints the board as ASCII for one mode+seed (# crate, M stone, N neutral castle, w wall,
## digits player castles).  godot --headless --fixed-fps 30 res://tools/dump_board.tscn -- --mode=versus --seed=4 --terrain=6
const Main = preload("res://scripts/Main.gd")

func _ready() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Main.requested_mode = args.get("mode", "versus")
	var requested: Dictionary = {"seed": args.get("seed", "4"), "no-decorations": "true"}
	if args.has("terrain"):
		requested["terrain"] = args["terrain"]
	Main.requested_args = requested
	var main := Main.new()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var map = main.game.map
	var lines: Array = []
	for z in map.sizeZ:
		var row := ""
		for x in map.sizeX:
			var t = map.tiles[x][z]
			var ch := "."
			if t.water:
				ch = "~"
			if U.alive(t.structure):
				var terr: Variant = U.comp(t.structure, "Terrain")
				var castle: Variant = U.comp(t.structure, "Castle")
				if terr != null:
					ch = "#" if terr.destructible else "M"
				elif castle != null:
					ch = "N" if castle.owner() == null else str(castle.owner().playerID)
				elif U.comp(t.structure, "BuildingBlock") != null:
					ch = "w"
				else:
					ch = "?"
			row += ch
		lines.append("%2d %s" % [z, row])
	for l in lines:
		print(l)
	var heights: Array = []
	for z in map.sizeZ:
		var row := ""
		for x in map.sizeX:
			var t = map.tiles[x][z]
			var terr: Variant = U.comp(t.structure, "Terrain") if U.alive(t.structure) else null
			row += str(terr.columns[t]) if terr != null and terr.columns.has(t) else "."
		heights.append("%2d %s" % [z, row])
	for l in heights:
		print(l)
	for c in map.castles:
		var cc: Vector2i = map.tile_index_at(c.go.global_position)
		print("castle owner=%s centre=(%d,%d)" % [c.owner().playerID if c.owner() != null else "neutral", cc.x, cc.y])
	var blocked := {"top": 0, "bottom": 0}
	var sorts := {"rock": 0, "hill": 0}
	for go in map.terrain_features:
		var terr: Variant = U.comp(go, "Terrain")
		sorts["rock" if terr.destructible else "hill"] += 1
		for t in terr.tiles:
			blocked["top" if t.idxZ < map.sizeZ / 2 else "bottom"] += 1
	var touching := 0
	var feats: Array = []
	for go in map.terrain_features:
		var cells: Array = U.comp(go, "Terrain").tiles.map(
				func(t): return Vector2i(t.idxX, t.idxZ))
		feats.append(cells)
	for i in feats.size():
		for j in range(i + 1, feats.size()):
			var gap := 99
			for a in feats[i]:
				for b in feats[j]:
					gap = mini(gap, maxi(absi(a.x - b.x), absi(a.y - b.y)))
			if gap <= 1:
				touching += 1
	var tall := 0
	var blocks := 0
	for go in map.terrain_features:
		var terr2: Variant = U.comp(go, "Terrain")
		for t in terr2.tiles:
			var h: int = terr2.columns[t]
			blocks += h
			if h >= 2:
				tall += 1
	print("features=%d (%d rock, %d hill), blocked tiles: top %d, bottom %d of %d a half, touching pairs %d, columns 2+ high %d of %d blocks"
			% [map.terrain_features.size(), sorts["rock"], sorts["hill"],
				blocked["top"], blocked["bottom"], map.sizeX * map.sizeZ / 2, touching, tall, blocks])
	get_tree().quit()
