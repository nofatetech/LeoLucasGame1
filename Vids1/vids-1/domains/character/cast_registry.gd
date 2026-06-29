# CastRegistry - resolves a character id to its hand-editable scene by scanning universes.
# Characters live in universes/<universe>/characters/<id>.tscn; the file basename is the id.
# Add a character = drop a scene in that folder (no code edits). See docs/plan-universe.md.
class_name CastRegistry
extends RefCounted

const UNIVERSES_DIR := "res://universes"

static var _index: Dictionary = {}   # id -> scene path (lazily built)

static func has(id: String) -> bool:
	return _scene_path(id) != ""

## Instantiate a character by id, or null if unknown.
static func create(id: String) -> Character:
	var path := _scene_path(id)
	if path == "":
		return null
	var scene: PackedScene = load(path)
	return scene.instantiate() if scene else null

## All known character ids across every universe.
static func ids() -> Array:
	_ensure_index()
	return _index.keys()

static func rescan() -> void:
	_index.clear()
	_ensure_index()

# --- internals ---

static func _scene_path(id: String) -> String:
	_ensure_index()
	return _index.get(id, "")

static func _ensure_index() -> void:
	if not _index.is_empty():
		return
	var universes := DirAccess.open(UNIVERSES_DIR)
	if universes == null:
		return
	universes.list_dir_begin()
	var u := universes.get_next()
	while u != "":
		if universes.current_is_dir() and not u.begins_with("."):
			_index_characters(UNIVERSES_DIR.path_join(u).path_join("characters"))
		u = universes.get_next()
	universes.list_dir_end()

static func _index_characters(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.ends_with(".tscn"):
			_index[f.get_basename()] = dir.path_join(f)
		f = d.get_next()
	d.list_dir_end()
