# CharacterData - identity + bible for a character. Two ways to give it a LOOK:
#   1. Bespoke: hand-draw a cast scene (universes/<u>/characters/<id>.tscn); this holds only
#      the non-visual identity. Max control — used for heroes.
#   2. Data-driven: drop this resource as <id>.tres; the shared character_base.tscn builds the
#      look from the "Look" fields below (procedural shapes OR image cutouts). No scene to author
#      — a character is just data. See CharacterArt / CastRegistry.
@tool
class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = "Character"

@export_group("Look")
## How the shared base scene draws this character. Ignored for bespoke .tscn characters.
##   "procedural" - flat shapes from the colors below (our default look).
##   "image"      - PNG/WebP/SVG cutouts from the textures below (public-domain / photo cast).
@export_enum("procedural", "image") var look := "procedural"
@export_subgroup("Procedural")
@export var body_color := Color(0.6, 0.6, 0.6)
@export var skin_color := Color(0.945, 0.76, 0.49)
@export var hair_color := Color(0.23, 0.16, 0.1)
@export var has_hair := true
@export var eye_color := Color(0, 0, 0)
@export_subgroup("Image")
## Whole standing figure (feet-to-head). Auto-scaled to the native cast height so the
## composition frames it like any other character, whatever the source resolution.
@export var body_texture: Texture2D
## Optional lip-sync cutouts, swapped by openness. Omit → the mouth just doesn't move.
@export var mouth_closed: Texture2D
@export var mouth_open: Texture2D
## Where the mouth sits, relative to the character's feet-at-origin (image look only).
@export var mouth_offset := Vector2(0, -140)

@export_group("Language & Voice")
## Character's main language ("" = inherit from episode/show). Overrides episode default,
## is itself overridden by a per-line @lang. See docs/plan-studio-panel.md.
@export var language: String = ""
## Maps language code -> Piper voice model name, e.g. {"es": "es_MX-claude-high"}.
## Having >1 entry is what makes a character multilingual. Empty -> placeholder tone.
@export var voices: Dictionary = {}
## Placeholder-tone pitch multiplier, used only when no real voice is available for a line.
@export var voice_pitch: float = 1.0

@export_group("Bible")
## Reusable character lore — shared across any production in the universe. All optional.
@export_multiline var bio: String = ""
@export var personality: String = ""
@export var relationships: Dictionary = {}   # other character id -> label, e.g. "brother"
@export var catchphrases: Array = []
@export var tags: Array = []                  # free-form, e.g. ["kid", "lead"]

## The voice model name for a resolved language, or "" if none.
func voice_for(lang: String) -> String:
	return voices.get(lang, "")
