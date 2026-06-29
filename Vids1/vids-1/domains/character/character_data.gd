# CharacterData - non-visual identity for a character. The LOOK lives in the hand-editable
# cast scene (domains/character/cast/*.tscn); this holds what the Director needs that isn't
# visual: identity, language, and per-language TTS voices. Assigned inline on the cast root.
class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = "Character"

@export_group("Language & Voice")
## Character's main language ("" = inherit from episode/show). Overrides episode default,
## is itself overridden by a per-line @lang. See docs/plan-studio-panel.md.
@export var language: String = ""
## Maps language code -> Piper voice model name, e.g. {"es": "es_MX-claude-high"}.
## Having >1 entry is what makes a character multilingual. Empty -> placeholder tone.
@export var voices: Dictionary = {}
## Placeholder-tone pitch multiplier, used only when no real voice is available for a line.
@export var voice_pitch: float = 1.0

## The voice model name for a resolved language, or "" if none.
func voice_for(lang: String) -> String:
	return voices.get(lang, "")
