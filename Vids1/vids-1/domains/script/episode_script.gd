# EpisodeScript - the parsed form of an episode .md, fed to the Director.
# Beats are a flat, ordered list (scenes are recorded per-beat for later structure).
# Beat shapes (Dictionary):
#   {type:"say",  speaker:<cast id>, text:String, emote:String, scene:String}
#   {type:"wait", seconds:float}
# Directives other than [wait] are parsed but not yet executed (M2/M3).
class_name EpisodeScript
extends Resource

@export var episode: String = ""
@export var title: String = ""
@export var language: String = ""     # episode default language ("" = inherit show/global)
@export var cast: Dictionary = {}     # alias -> cast id
@export var beats: Array = []

## Resolve a dialogue alias to a cast id. Falls back to the alias itself.
func resolve(alias: String) -> String:
	return cast.get(alias, alias)
