extends Node
## Battle lab: plays a sandbox scenario many times and reports win rates and
## mean stats per side, optionally while sweeping one catalog value.
##
##   godot --headless --fixed-fps 30 res://tools/lab.tscn -- --scenario=flak_vs_cannons --runs=20
##
## Options (after "--"):
##   --scenario=NAME|PATH  saved name (user://scenarios), example name or a .tres path
##   --runs=N              battles per setting (default 10); seeds --seed .. --seed+N-1
##   --seed=N              first seed (default 1)
##   --match=ai|dormant    AI vs AI (default) or blue AI vs a red AI that never fires
##   --targets=B,R         what each AI aims at: walls, guns, supply, random (default walls,walls)
##   --swap=false          by default every seed is played twice, the second time with
##                         the layouts swapped (mirrored to the other side, other
##                         colour): blue / red in the results mean blue's / red's
##                         layout, whoever played it. Battles are decided by who
##                         breaches a wall first, and in a tie the side processed
##                         first (blue) wins, so this keeps the comparison fair.
##   --limit=SECONDS       time limit per battle (default 180)
##   --speed=F             game speed per frame (default 1; faster is coarser)
##   --set=ID.FIELD=V      change a catalog value first (several: separate with ";")
##   --sweep=ID.FIELD=A:B:STEP or =V1,V2,...   repeat everything for each value
##   --csv=PATH            one row per battle
##   --out=PATH            progress ("running k/n") while running, then the result table
##                         (used by the Sandbox's Run button)
##
## ID.FIELD: a building id and a field of its def or of one of its behaviours,
## e.g. flak22.salvo_interval, cannon.reload, supply.produces.supply,
## cannon.projectile.splash_range.

const SandboxScene = preload("res://scenes/sandbox.tscn")
const STATS := ["shots", "hits", "intercepted", "absorbed", "walls_lost", "guns_lost", "castles_lost", "buildings_lost"]
const RESULTS := ["blue", "red", "draw"]

var args := {}
var sb: Node
## one Dictionary per battle: value, seed, winner, time, b_<stat>, r_<stat>
var rows: Array = []
var layout: Array = []
var swapped_layout: Array = []
var targets: Array = []


func _ready() -> void:
	# exact frame steps from the first frame on, so a seed always gives the same battle
	Engine.physics_jitter_fix = 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var code := await run()
	get_tree().quit(code)


func run() -> int:
	var path := scenario_path(str(args.get("scenario", "")))
	if path == "":
		printerr("lab: no scenario '%s' (give a saved name, an example name or a .tres path)" % args.get("scenario", ""))
		return 2
	for change in str(args.get("set", "")).split(";", false):
		var kv := change.split("=", true, 1)
		var err := set_value(kv[0].strip_edges(), kv[1] if kv.size() > 1 else "")
		if err != "":
			printerr("lab: " + err)
			return 2
	var field := ""
	var values: Array = [null]
	if args.has("sweep"):
		var kv := str(args["sweep"]).split("=", true, 1)
		field = kv[0].strip_edges()
		values = sweep_values(kv[1] if kv.size() > 1 else "")
		if values.is_empty() or get_value(field) == null:
			printerr("lab: bad --sweep '%s'" % args["sweep"])
			return 2
	var original = get_value(field) if field != "" else null

	sb = SandboxScene.instantiate()
	sb.decorate = false
	add_child(sb)
	await get_tree().process_frame
	if not sb.load_scenario(path):
		printerr("lab: cannot load " + path)
		return 2
	sb.match_index = 3 if args.get("match", "ai") == "dormant" else 0
	var t := str(args.get("targets", "walls,walls")).split(",")
	targets = [t[0].strip_edges(), t[mini(1, t.size() - 1)].strip_edges()]
	layout = sb.snapshot()
	swapped_layout = layout.map(func(it): return sb.mirrored(it, 1 - it["side"], sb.map.sizeZ))
	var swap: bool = str(args.get("swap", "true")) != "false"
	sb.time_limit = float(args.get("limit", "180"))
	sb.speed = float(args.get("speed", "1"))
	var runs := int(args.get("runs", "10"))
	var first_seed := int(args.get("seed", "1"))

	print("Battle lab: %s, %d seed(s) per setting (%d-%d)%s, %s, targets %s / %s, limit %d s, speed %sx" % [
		path.get_file().get_basename(), runs, first_seed, first_seed + runs - 1,
		", each also with the layouts swapped" if swap else "", sb.MATCHES[sb.match_index],
		targets[0], targets[1], sb.time_limit, sb.speed])
	var total := runs * values.size() * (2 if swap else 1)
	for v in values:
		if field != "":
			set_value(field, str(v))
		for i in runs:
			for swapped in ([false, true] if swap else [false]):
				_write_out("running %d/%d" % [rows.size(), total])
				var row := await battle(first_seed + i, v, swapped)
				rows.append(row)
				print("  %sseed %d%s: %s after %.1f s" % ["" if v == null else "%s=%s " % [field, v],
					row["seed"], " swapped" if swapped else "",
					"draw" if row["winner"] == "draw" else row["winner"] + "'s layout wins", row["time"]])
	if field != "":
		set_value(field, str(original))
	print(table(field, values))
	_write_out(summary(field, values))
	if args.has("csv"):
		write_csv(str(args["csv"]), field)
	return 0


## Plays one battle and returns its row; "b_" / "r_" and the winner refer to
## blue's / red's layout, also when the layouts were swapped.
func battle(battle_seed: int, value, swapped := false) -> Dictionary:
	sb.restore(swapped_layout if swapped else layout)
	for s in 2:  # settings follow the layout
		sb.targets[s] = targets[1 - s if swapped else s]
	sb.dormant_side = 0 if swapped else 1
	sb.scenario.seed = battle_seed
	sb.play()
	while sb.mode == sb.Mode.BATTLE:
		await get_tree().process_frame
	var w: int = sb.winner
	if swapped and w < 2:
		w = 1 - w
	var row := {"value": value, "seed": battle_seed, "swapped": swapped, "winner": RESULTS[w],
		"time": snappedf(sb.battle_time(), 0.1)}
	for s in 2:
		var st: Dictionary = sb.player(1 - s if swapped else s).stats
		for k in STATS:
			row["br"[s] + "_" + k] = int(st.get(k, 0))
	sb.reset()
	return row


func table(field: String, values: Array) -> String:
	var w := maxi(12, field.length())
	var head := ("%-" + str(w) + "s %5s %5s %5s %7s | %s | %s") % [
		field if field != "" else "", "blue", "red", "draw", "time",
		"blue: shots hits intc absb walls guns castl", "red: shots hits intc absb walls guns castl"]
	var lines := [head, "-".repeat(head.length())]
	for v in values:
		var sel := rows.filter(func(r): return r["value"] == v)
		var n := float(sel.size())
		var line := ("%-" + str(w) + "s") % (str(v) if v != null else "")
		for res in RESULTS:
			line += " %4d%%" % roundi(100.0 * sel.filter(func(r): return r["winner"] == res).size() / n)
		line += " %6.1fs" % (sel.reduce(func(a, r): return a + r["time"], 0.0) / n)
		for side in "br":
			line += " |"
			for k in ["shots", "hits", "intercepted", "absorbed", "walls_lost", "guns_lost", "castles_lost"]:
				var mean: float = sel.reduce(func(a, r): return a + r[side + "_" + k], 0.0) / n
				line += " %4.1f" % mean
			line += "      " if side == "b" else ""
		lines.append(line)
	return "\n".join(lines)


## Compact result per setting, one column per side (the Sandbox shows it).
func summary(field: String, values: Array) -> String:
	var out: Array[String] = []
	for v in values:
		var sel := rows.filter(func(r): return r["value"] == v)
		var n := float(sel.size())
		if v != null:
			out.append("%s = %s" % [field, v])
		out.append("%d battles (seeds %d-%d%s), mean %.1f s" % [n, sel[0]["seed"], sel[-1]["seed"],
			", also swapped" if sel[-1]["swapped"] else "", sel.reduce(func(a, r): return a + r["time"], 0.0) / n])
		var pct := func(w): return roundi(100.0 * sel.filter(func(r): return r["winner"] == w).size() / n)
		out.append("Blue's layout wins %d%%\nRed's layout wins %d%%\nDraw %d%%" % [pct.call("blue"), pct.call("red"), pct.call("draw")])
		out.append("%-14s %6s %6s" % ["mean", "blue", "red"])
		for k in STATS:
			var m := []
			for side in "br":
				m.append(sel.reduce(func(a, r): return a + r[side + "_" + k], 0.0) / n)
			out.append("%-14s %6.1f %6.1f" % [k.replace("_", " "), m[0], m[1]])
	return "\n".join(out)


func _write_out(text: String) -> void:
	if not args.has("out"):
		return
	var f := FileAccess.open(str(args["out"]), FileAccess.WRITE)
	if f != null:
		f.store_string(text)


func write_csv(path: String, field: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("lab: cannot write " + path)
		return
	var cols := ["value", "seed", "swapped", "winner", "time"]
	for side in "br":
		for k in STATS:
			cols.append(side + "_" + k)
	var head := PackedStringArray(cols)
	head[0] = field if field != "" else "value"
	f.store_line(",".join(head))
	for r in rows:
		f.store_line(",".join(PackedStringArray(cols.map(func(c): return "" if r[c] == null else str(r[c])))))
	print("lab: wrote %d rows to %s" % [rows.size(), path])


# ------------------------------------------------------------ helpers
static func scenario_path(name: String) -> String:
	if name == "":
		return ""
	var tries := [name, "user://scenarios/%s.tres" % name, "res://data/scenarios/%s.tres" % name]
	for p in tries:
		if p.ends_with(".tres") and (FileAccess.file_exists(p) or ResourceLoader.exists(p)):
			return p
	return ""


static func sweep_values(spec: String) -> Array:
	var out: Array = []
	if spec.contains(":"):
		var p := spec.split(":")
		if p.size() != 3 or float(p[2]) <= 0.0:
			return []
		var v := float(p[0])
		while v <= float(p[1]) + 1e-6:
			out.append(snappedf(v, 0.0001))
			v += float(p[2])
	else:
		for v in spec.split(",", false):
			out.append(v.strip_edges())
	return out


## Resolves "id.a.b": the def, then fields of the def, its behaviours or
## resources / dictionaries below. Returns [owner, key] or [] if not found.
static func _resolve(path: String) -> Array:
	var parts := path.split(".")
	if parts.size() < 2:
		return []
	var obj = Catalog.get_def(parts[0])
	if obj == null:
		return []
	for i in range(1, parts.size()):
		var key := parts[i]
		var owner = obj
		if obj is BuildingDef and not (key in obj):
			owner = null
			for b in obj.behaviours:
				if b != null and key in b:
					owner = b
					break
		if owner == null or not (key in owner or (owner is Dictionary and owner.has(key))):
			return []
		if i == parts.size() - 1:
			return [owner, key]
		obj = owner[key] if owner is Dictionary else owner.get(key)
	return []


static func get_value(path: String):
	var r := _resolve(path)
	if r.is_empty():
		return null
	return r[0][r[1]] if r[0] is Dictionary else r[0].get(r[1])


## Sets a catalog value from text, keeping the field's type. Returns an error or "".
static func set_value(path: String, text: String) -> String:
	var r := _resolve(path)
	if r.is_empty():
		return "unknown value '%s' (use <building id>.<field>)" % path
	var old = get_value(path)
	var v
	match typeof(old):
		TYPE_INT:
			v = int(text)
		TYPE_FLOAT:
			v = float(text)
		TYPE_BOOL:
			v = text.to_lower() in ["true", "1", "yes"]
		TYPE_STRING:
			v = text
		_:
			return "'%s' is not a number, flag or text" % path
	if r[0] is Dictionary:
		r[0][r[1]] = v
	else:
		r[0].set(r[1], v)
	return ""
