# CastRegistry - resolves a character id to its cast member by scanning universes.
# Characters live in universes/<universe>/characters/<id>, where the file is either:
#   - <id>.tscn : a bespoke hand-drawn scene (heroes), OR
#   - <id>.tres : CharacterData only — built on the shared character_base.tscn (data-driven).
# The file basename is the id; a .tscn wins if both exist. Add a character = drop a file in
# that folder (no code edits). See docs/plan-universe.md.
class_name CastRegistry
extends RefCounted

const UNIVERSES_DIR := "res://universes"
const BASE_SCENE := "res://domains/character/character_base.tscn"

static var _index: Dictionary = {}   # id -> scene path (lazily built)

static func has(id: String) -> bool:
	return _scene_path(id) != ""

## Instantiate a character by id, or null if unknown. A .tscn is instantiated directly;
## a .tres (CharacterData) is built on the shared base scene with its data assigned.
static func create(id: String) -> Character:
	var path := _scene_path(id)
	if path == "":
		return null
	if path.ends_with(".tres"):
		var data := load(path) as CharacterData
		if data == null:
			return null
		var base := load(BASE_SCENE) as PackedScene
		var c := base.instantiate() as Character
		if c:
			c.data = data   # set before it enters the tree so _ready builds the look
		return c
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
		if f.ends_with(".tscn") or f.ends_with(".tres"):
			var id := f.get_basename()
			# A bespoke .tscn wins over a .tres of the same id.
			if not (_index.has(id) and _index[id].ends_with(".tscn")):
				_index[id] = dir.path_join(f)
		f = d.get_next()
	d.list_dir_end()
