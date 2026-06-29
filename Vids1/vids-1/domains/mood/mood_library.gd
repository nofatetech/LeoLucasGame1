# MoodLibrary - resolves a mood name to a Mood. Built-in presets work out of the box;
# a universes/<u>/moods/<name>.tres overrides/extends them (names over paths). See plan-universe.md.
class_name MoodLibrary
extends RefCounted

const UNIVERSES_DIR := "res://universes"

# name -> [bg_color, pace, voice_length_scale, voice_noise_scale]
const BUILTIN := {
	"happy":  [Color(0.53, 0.81, 0.92), 1.0,  1.0,  0.70],
	"tense":  [Color(0.20, 0.22, 0.30), 1.12, 1.15, 0.45],
	"calm":   [Color(0.70, 0.85, 0.85), 1.12, 1.12, 0.55],
	"spooky": [Color(0.10, 0.10, 0.16), 1.15, 1.18, 0.50],
	"manic":  [Color(0.98, 0.85, 0.45), 0.75, 0.85, 0.85],
}

## Returns a Mood for the name, or null if name is "" / unknown.
static func get_mood(name: String) -> Mood:
	if name == "":
		return null
	var path := _tres_path(name)
	if path != "":
		return load(path)
	if BUILTIN.has(name):
		return _from_preset(name, BUILTIN[name])
	push_warning("Unknown mood '%s', ignoring" % name)
	return null

static func _from_preset(name: String, p: Array) -> Mood:
	var m := Mood.new()
	m.id = name
	m.bg_color = p[0]
	m.pace = p[1]
	m.voice_length_scale = p[2]
	m.voice_noise_scale = p[3]
	return m

static func _tres_path(name: String) -> String:
	var universes := DirAccess.open(UNIVERSES_DIR)
	if universes == null:
		return ""
	universes.list_dir_begin()
	var u := universes.get_next()
	while u != "":
		if universes.current_is_dir() and not u.begins_with("."):
			var candidate := UNIVERSES_DIR.path_join(u).path_join("moods").path_join(name + ".tres")
			if FileAccess.file_exists(candidate):
				universes.list_dir_end()
				return candidate
		u = universes.get_next()
	universes.list_dir_end()
	return ""
