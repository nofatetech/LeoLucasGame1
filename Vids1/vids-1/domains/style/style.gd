# Style - a render-look preset: output resolution/aspect + an optional fullscreen post shader.
# Resolved most-specific-first like mood: episode `style:` -> show/season (--style) -> none.
# Built-ins in StyleLibrary; override via universes/<u>/styles/<id>.tres. See plan-templates.md.
@tool
class_name Style
extends Resource

@export var id: String = ""
## Output size. (0,0) = inherit / leave the project default (1280x720).
@export var resolution: Vector2i = Vector2i(0, 0)
## Fullscreen post effect: "" | "anaglyph" | "bw" | "crt".
@export var shader: String = ""

func has_resolution() -> bool:
	return resolution.x > 0 and resolution.y > 0
