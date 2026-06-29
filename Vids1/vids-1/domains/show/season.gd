# Season - groups episodes under a Show. Can override the show's language.
@tool
class_name Season
extends Resource

@export var title: String = ""
@export var number: int = 1
@export var language: String = ""    # "" = inherit show default
@export var episodes: Array = []     # Array of EpisodeRef
