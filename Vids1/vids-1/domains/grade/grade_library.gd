# GradeLibrary - resolves a grade name to a Grade. Built-ins cover the common looks; drop a
# universes/<u>/grades/<name>.tres to add/override (names over paths), like Mood/Style.
class_name GradeLibrary
extends RefCounted

const UNIVERSES_DIR := "res://universes"

# name -> [tint, contrast, saturation, temperature, vignette, grain]
const BUILTIN := {
	"neutral": [Color(1, 1, 1),          1.0,  1.0,   0.0,  0.0,  0.0],
	"warm":    [Color(1.0, 0.96, 0.88),  1.05, 1.08,  0.25, 0.15, 0.04],
	"noir":    [Color(0.90, 0.95, 1.0),  1.25, 0.35, -0.25, 0.45, 0.10],
	"dream":   [Color(1.0, 0.97, 0.95),  0.90, 1.20,  0.15, 0.30, 0.05],
	"flash":   [Color(1.25, 1.25, 1.25), 1.10, 1.0,   0.0,  0.0,  0.0],
}

static func get_grade(name: String) -> Grade:
	if name == "":
		return null
	var path := _tres_path(name)
	if path != "":
		return load(path)
	if BUILTIN.has(name):
		return _from_preset(name, BUILTIN[name])
	push_warning("Unknown grade '%s', ignoring" % name)
	return null

static func _from_preset(name: String, p: Array) -> Grade:
	var g := Grade.new()
	g.id = name
	g.tint = p[0]
	g.contrast = p[1]
	g.saturation = p[2]
	g.temperature = p[3]
	g.vignette = p[4]
	g.grain = p[5]
	return g

static func _tres_path(name: String) -> String:
	var universes := DirAccess.open(UNIVERSES_DIR)
	if universes == null:
		return ""
	universes.list_dir_begin()
	var u := universes.get_next()
	while u != "":
		if universes.current_is_dir() and not u.begins_with("."):
			var candidate := UNIVERSES_DIR.path_join(u).path_join("grades").path_join(name + ".tres")
			if FileAccess.file_exists(candidate):
				universes.list_dir_end()
				return candidate
		u = universes.get_next()
	universes.list_dir_end()
	return ""
