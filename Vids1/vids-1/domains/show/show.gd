# Show - root of a series. Series-wide defaults (language, fps, resolution, output dir)
# that trickle down to seasons/episodes, plus the season list. Hand-editable .tres; the
# Studio dock lists and renders from it. See docs/plan-studio-panel.md.
@tool
class_name Show
extends Resource

@export var title: String = ""
@export var universe: String = ""   # universe id this show casts from
@export var default_language: String = ""
@export var style: String = ""      # default render style (resolution + post shader)
@export var fps: int = 30
@export var resolution: Vector2i = Vector2i(1280, 720)
@export_dir var output_dir: String = "res://output"
@export var seasons: Array = []   # Array of Season
