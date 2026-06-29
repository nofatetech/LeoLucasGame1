# Mood - a named preset that reshapes a scene: background tint, pacing, and voice delivery
# (Piper length/noise scale). Resolved most-specific-first, like language:
#   scene {mood:x} -> episode mood: -> show/season (--mood) -> none.
# Built-ins live in MoodLibrary; drop universes/<u>/moods/<id>.tres to add/override.
@tool
class_name Mood
extends Resource

@export var id: String = ""

@export_group("Visual")
## Background tint. Alpha 0 = leave the scene's default background.
@export var bg_color: Color = Color(0, 0, 0, 0)

@export_group("Timing")
## Scales the gap between beats (>1 slower / more deliberate, <1 snappier).
@export var pace: float = 1.0

@export_group("Voice (Piper)")
## >1 slows speech, <1 speeds it up.
@export var voice_length_scale: float = 1.0
## Expressiveness/variation; Piper's default is 0.667. Lower = flatter/colder.
@export var voice_noise_scale: float = 0.667

@export_group("Cinematography")
## Name of a Grade preset this mood implies. "" = neutral. Overridable by scene {grade:}
## or a [grade:] beat. See plan-moviemaking.md.
@export var grade: String = ""

func has_bg() -> bool:
	return bg_color.a > 0.0
