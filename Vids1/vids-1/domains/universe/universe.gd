# Universe - a shared world: reusable characters (and later sets/moods) that any production
# (Show or Movie) can cast from. Characters are discovered from the universe's characters/
# folder by CastRegistry, so this resource is mostly identity + lore. See docs/plan-universe.md.
@tool
class_name Universe
extends Resource

@export var id: String = ""
@export var title: String = ""
@export_multiline var lore: String = ""
