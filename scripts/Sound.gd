extends Node
## Sound (autoload): the game's clips by cue, the three buses and one call per event.
##
## A clip is res://assets/audio/<bus>/<cue>.wav or <cue>_<n>.wav for a cue with variants, picked at random and
## never the same twice in a row. A cue without a clip plays nothing, so a hook may stand before its clip lands.
## The cue list and the hooks are in art/game/design/sound.md. The music is res://assets/audio/music/<cue>.ogg,
## looped. The clips draw their randomness from here, never from the game's sequence (seeded battles stay).

const DIRS := {"SFX": "res://assets/audio/sfx", "UI": "res://assets/audio/ui"}
const MUSIC_DIR := "res://assets/audio/music"
## A cue played with another cue's clip while it has none of its own: cue -> [clip cue, dB].
const ALIAS := {
	"ui_hover": ["ui_click", -8.0],
	"countdown": ["ui_click", -4.0],
	"horn_guns": ["horn_battle", -6.0],
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
var _rng := RandomNumberGenerator.new()
## Headless runs (tests, the lab) have no audio device: the voices keep their books by the clock and never
## start a playback, which the server would hold past the resource cache at exit and report as a leak.
var _silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
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


## Every Button under `root` clicks and ticks on hover.
func buttons(root: Node) -> void:
	for n in root.find_children("*", "Button", true, false):
		n.pressed.connect(play.bind("ui_click"))
		n.mouse_entered.connect(play.bind("ui_hover"))
	if root is Button:
		root.pressed.connect(play.bind("ui_click"))
		root.mouse_entered.connect(play.bind("ui_hover"))
