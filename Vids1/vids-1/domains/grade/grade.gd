# Grade - a color-grade preset (the "look" of the frame). Applied as a fullscreen post pass
# below the style shaders. Resolved most-specific-first like mood/style:
#   beat [grade:x] -> scene {grade:x} -> the active mood's grade -> neutral.
# Built-ins in GradeLibrary; override via universes/<u>/grades/<id>.tres. See plan-moviemaking.md.
@tool
class_name Grade
extends Resource

@export var id: String = ""

## Multiplied over the frame. White = no change.
@export var tint: Color = Color(1, 1, 1)
## Push/pull around mid-grey. 1 = unchanged.
@export_range(0.5, 2.0) var contrast: float = 1.0
## 0 = greyscale, 1 = unchanged, >1 = punchier.
@export_range(0.0, 2.0) var saturation: float = 1.0
## -1 cool (blue) .. 0 neutral .. +1 warm (orange).
@export_range(-1.0, 1.0) var temperature: float = 0.0
## Corner darkening, 0 = off.
@export_range(0.0, 1.0) var vignette: float = 0.0
## Film grain amount, 0 = off. Deterministic under Movie Maker (fixed per-frame TIME).
@export_range(0.0, 1.0) var grain: float = 0.0
