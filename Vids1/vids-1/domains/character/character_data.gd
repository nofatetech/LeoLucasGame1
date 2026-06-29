# CharacterData - non-visual identity for a character. The LOOK now lives in the
# hand-editable cast scene (domains/character/cast/*.tscn); this holds only what the
# Director needs that isn't visual. Assigned inline on each cast scene's root.
class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = "Character"

@export_group("Voice")
## Placeholder-tone pitch multiplier in M0/M1; real voice id comes in M2.
@export var voice_pitch: float = 1.0
