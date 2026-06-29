# CastRegistry - maps a character id (used in scripts) to its hand-editable cast scene.
# Add a new character: draw domains/character/cast/<id>.tscn, then register it here.
# In M1 the parser resolves script aliases (frontmatter `cast:`) to these ids.
class_name CastRegistry
extends RefCounted

const CAST := {
	"leo": preload("res://domains/character/cast/leo.tscn"),
	"lucas": preload("res://domains/character/cast/lucas.tscn"),
}

static func has(id: String) -> bool:
	return CAST.has(id)

## Instantiate a character by id, or null if unknown.
static func create(id: String) -> Character:
	var scene: PackedScene = CAST.get(id)
	return scene.instantiate() if scene else null
