# StyleLibrary - resolves a style name to a Style. Built-ins cover aspect presets (for
# Shorts/Reels) and post shaders (anaglyph/bw/crt); override via universes/<u>/styles/<id>.tres.
class_name StyleLibrary
extends RefCounted

const UNIVERSES_DIR := "res://universes"

# name -> [resolution, shader]
const BUILTIN := {
	"wide":     [Vector2i(1280, 720),  ""],
	"vertical": [Vector2i(1080, 1920), ""],   # 9:16 — Shorts / Reels / TikTok
	"square":   [Vector2i(1080, 1080), ""],   # 1:1
	"anaglyph": [Vector2i(0, 0),       "anaglyph"],
	"bw":       [Vector2i(0, 0),       "bw"],
	"crt":      [Vector2i(0, 0),       "crt"],
}

static func get_style(name: String) -> Style:
	if name == "":
		return null
	var path := _tres_path(name)
	if path != "":
		return load(path)
	if BUILTIN.has(name):
		var p: Array = BUILTIN[name]
		var s := Style.new()
		s.id = name
		s.resolution = p[0]
		s.shader = p[1]
		return s
	push_warning("Unknown style '%s', ignoring" % name)
	return null

static func _tres_path(name: String) -> String:
	var universes := DirAccess.open(UNIVERSES_DIR)
	if universes == null:
		return ""
	universes.list_dir_begin()
	var u := universes.get_next()
	while u != "":
		if universes.current_is_dir() and not u.begins_with("."):
			var candidate := UNIVERSES_DIR.path_join(u).path_join("styles").path_join(name + ".tres")
			if FileAccess.file_exists(candidate):
				universes.list_dir_end()
				return candidate
		u = universes.get_next()
	universes.list_dir_end()
	return ""
