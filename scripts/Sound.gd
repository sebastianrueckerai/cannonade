extends Node
## Sound (autoload): the game's clips by cue, the three buses, the menu's volumes and one call per event.
##
## A clip is res://assets/audio/<bus>/<cue>.wav or <cue>_<n>.wav for a cue with variants, picked at random and
## never the same twice in a row. A cue without a clip plays nothing, so a hook may stand before its clip lands.
## The cue list and the hooks are in art/game/design/sound.md. The music is res://assets/audio/music/<cue>.ogg,
## looped. The clips draw their randomness from here, never from the game's sequence (seeded battles stay).

const DIRS := {"SFX": "res://assets/audio/sfx", "UI": "res://assets/audio/ui"}
const MUSIC_DIR := "res://assets/audio/music"
const VOLUME_PATH := "user://volume.cfg"
## One slider of the menu's Volume panel; "sound" is both effect buses, the battle clips and the UI clicks.
const VOLUME_BUSES := {"master": ["Master"], "sound": ["SFX", "UI"], "music": ["Music"]}
## The settings' labels in the sliders, for the menu's Volume panel and the game's pause menu.
const VOLUME_LABELS := {"master": "Master", "sound": "Sound", "music": "Music"}
## A cue played with another cue's clip while it has none of its own: cue -> [clip cue, dB].
const ALIAS := {
	"ui_hover": ["ui_click", -8.0],
	"countdown": ["ui_click", -4.0],
	"shot_ship": ["shot_cannon", -6.0],
	"stack_block": ["place_piece", 2.0],
	"hit_gun": ["hit_wall", 0.0],
	"hit_castle": ["hit_wall", 0.0],
}
## Voices a cue may hold at once; the oldest is stolen.
const VOICES := 3
## Another player's action, against the own player's.
const OTHER_DB := -6.0

var _clips := {}  # cue -> [bus, Array[AudioStream]]
var _last := {}  # cue -> the variant played last
var _voices: Array[AudioStreamPlayer] = []
var _music := AudioStreamPlayer.new()
var _music_cue := ""
var _volume := {}  # setting of VOLUME_BUSES -> linear 0 to 1, 1 when never saved
var _rng := RandomNumberGenerator.new()
## Headless runs (tests, the lab) have no audio device: the voices keep their books by the clock and never
## start a playback, which the server would hold past the resource cache at exit and report as a leak.
var _silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
	load_volumes()
	for bus in DIRS:
		for f in _files(DIRS[bus]):
			var stem: String = f.get_basename()
			var cue := stem
			var n := stem.rfind("_")
			if n > 0 and stem.substr(n + 1).is_valid_int():
				cue = stem.substr(0, n)
			var stream = load(DIRS[bus].path_join(f))
			if stream is AudioStream:
				_clips.get_or_add(cue, [bus, []])[1].append(stream)
	_music.bus = "Music"
	add_child(_music)


## Files of a res:// folder, by their source names: an exported game lists the `.import` sidecars instead.
static func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	for f in DirAccess.get_files_at(dir):
		var name: String = f.trim_suffix(".import")
		if (name.ends_with(".wav") or name.ends_with(".ogg")) and not seen.has(name):
			seen[name] = true
			out.append(name)
	return out


func has(cue: String) -> bool:
	return _clips.has(cue)


func variants(cue: String) -> int:
	return _clips[cue][1].size() if _clips.has(cue) else 0


## Plays a cue, `db` under its clip's level. The voice is on the clip's bus, SFX or UI.
func play(cue: String, db := 0.0) -> void:
	if not _clips.has(cue) and ALIAS.has(cue):
		db += ALIAS[cue][1]
		cue = ALIAS[cue][0]
	if not _clips.has(cue):
		return
	var streams: Array = _clips[cue][1]
	var i := _rng.randi_range(0, streams.size() - 1)
	if streams.size() > 1 and i == _last.get(cue, -1):
		i = (i + 1) % streams.size()
	_last[cue] = i
	var v := _voice(cue)
	v.bus = _clips[cue][0]
	v.stream = streams[i]
	v.volume_db = db
	v.set_meta("cue", cue)
	v.set_meta("since", Time.get_ticks_msec())
	v.set_meta("until", Time.get_ticks_msec() + int(streams[i].get_length() * 1000.0))
	if not _silent:
		v.play()


## A voice plays until its clip ends, by the clock.
static func _live(v: AudioStreamPlayer) -> bool:
	return Time.get_ticks_msec() < v.get_meta("until", 0)


## The oldest voice of the cue once it holds VOICES, else a free voice, else a new one.
func _voice(cue: String) -> AudioStreamPlayer:
	var mine: Array[AudioStreamPlayer] = []
	var free: AudioStreamPlayer = null
	for v in _voices:
		if not _live(v):
			free = v
		elif v.get_meta("cue") == cue:
			mine.append(v)
	if mine.size() >= VOICES:
		mine.sort_custom(func(a, b): return a.get_meta("since") < b.get_meta("since"))
		return mine[0]
	if free != null:
		return free
	var v := AudioStreamPlayer.new()
	add_child(v)
	_voices.append(v)
	return v


## Whether a voice of the cue plays now.
func playing(cue: String) -> bool:
	for v in _voices:
		if _live(v) and v.get_meta("cue") == cue:
			return true
	return false


## Starts the music cue, looped, unless it plays already. A missing file stops the music.
func music(cue: String) -> void:
	if cue == _music_cue:
		return
	var path := MUSIC_DIR.path_join(cue + ".ogg")
	_music.stop()
	_music_cue = cue if ResourceLoader.exists(path) else ""
	if _music_cue == "":
		return
	var stream = load(path)
	stream.loop = true
	_music.stream = stream
	if not _silent:
		_music.play()


func music_cue() -> String:
	return _music_cue


## The setting's linear volume, 1 when never saved.
func volume(kind: String) -> float:
	return _volume.get(kind, 1.0)


## Sets one setting, applies its buses and saves the file.
func set_volume(kind: String, linear: float) -> void:
	_volume[kind] = clampf(linear, 0.0, 1.0)
	_apply(kind)
	var cfg := ConfigFile.new()
	for k in VOLUME_BUSES:
		cfg.set_value("volume", k, _volume[k])
	cfg.save(VOLUME_PATH)


## Reads the saved volumes and applies them. A missing or broken file leaves everything at full.
func load_volumes() -> void:
	var cfg := ConfigFile.new()
	for kind in VOLUME_BUSES:
		_volume[kind] = 1.0
	if cfg.load(VOLUME_PATH) == OK:
		for kind in VOLUME_BUSES:
			var v = cfg.get_value("volume", kind, 1.0)
			if v is int or v is float:
				_volume[kind] = clampf(float(v), 0.0, 1.0)
	for kind in VOLUME_BUSES:
		_apply(kind)


## The setting's buses at its linear volume; the maxf is the -80 dB floor, a mute for the 0 slider.
func _apply(kind: String) -> void:
	var db := linear_to_db(maxf(_volume[kind], 0.0001))
	for bus in VOLUME_BUSES[kind]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), db)


## The Volume rows the menu's Volume panel and the game's pause menu share: one slider a setting, live on
## the buses and saved on every change.
func volume_rows() -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	for kind in VOLUME_BUSES:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		rows.add_child(line)
		var what := Label.new()
		what.text = VOLUME_LABELS[kind]
		what.custom_minimum_size = Vector2(110, 0)
		line.add_child(what)
		var slider := HSlider.new()
		slider.name = kind
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.scrollable = false
		slider.custom_minimum_size = Vector2(220, 32)
		slider.value = round(volume(kind) * 100)
		line.add_child(slider)
		var pct := Label.new()
		pct.name = kind + "_value"
		pct.custom_minimum_size = Vector2(56, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.text = "%d%%" % slider.value
		line.add_child(pct)
		slider.value_changed.connect(func(v: float) -> void:
			set_volume(kind, v / 100.0)
			pct.text = "%d%%" % roundi(v))
	return rows


## Every Button under `root` clicks and ticks on hover.
func buttons(root: Node) -> void:
	for n in root.find_children("*", "Button", true, false):
		n.pressed.connect(play.bind("ui_click"))
		n.mouse_entered.connect(play.bind("ui_hover"))
	if root is Button:
		root.pressed.connect(play.bind("ui_click"))
		root.mouse_entered.connect(play.bind("ui_hover"))
