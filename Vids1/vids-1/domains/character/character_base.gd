# CharacterBase - the shared scene for data-driven characters. It carries the Character
# contract (Voice + Mouth) but draws nothing by hand: CharacterArt builds the look from
# `data` at load. CastRegistry instantiates this and assigns `data` for any <id>.tres cast
# member, so a character can be pure data (no bespoke scene). See character_data.gd.
class_name CharacterBase
extends Character

func _ready() -> void:
	super()                      # Character: default data if unset
	CharacterArt.build(self, data)
