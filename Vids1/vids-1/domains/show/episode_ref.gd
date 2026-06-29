# EpisodeRef - points at an episode .md and carries per-episode overrides + bookkeeping.
# The .md stays the source of truth for content; this holds structure/params/status.
@tool
class_name EpisodeRef
extends Resource

@export var title: String = ""
@export var number: int = 1
@export_file("*.md") var md_path: String = ""
@export var language: String = ""    # "" = inherit season/show
@export var style: String = ""       # render style override ("" = inherit show)
@export var status: String = ""      # "", "rendered"
@export var last_output: String = "" # absolute path of last render
