# Character - behavior + contract for a cast member. Attach to the ROOT of a cast scene.
# The visuals are whatever shape nodes you draw by hand in that scene; this script only
# requires two named child nodes to exist:
#   - "Voice"  : an AudioStreamPlayer (the character's dialogue)
#   - "Mouth"  : a node with a set_open(amount: float) method (see mouth.gd)
# Both are optional-safe: a character with neither still runs, it just won't talk/flap.
class_name Character
extends Node2D

@export var data: CharacterData

var _wav: AudioStreamWAV
var _speaking := false
var mouth_open := 0.0   # 0 = closed, 1 = wide

func _ready() -> void:
	if data == null:
		data = CharacterData.new()

func _voice() -> AudioStreamPlayer:
	return get_node_or_null("Voice") as AudioStreamPlayer

func _mouth() -> Node:
	return get_node_or_null("Mouth")

## Begin speaking a (placeholder) clip. The mouth flaps from its amplitude.
func speak(wav: AudioStreamWAV) -> void:
	_wav = wav
	_speaking = true
	var v := _voice()
	if v:
		v.stream = wav
		v.play()

func stop_speaking() -> void:
	_speaking = false
	var v := _voice()
	if v:
		v.stop()

func _process(delta: float) -> void:
	var target := 0.0
	var v := _voice()
	if _speaking and v and v.playing and _wav != null:
		var amp := ClipAmplitude.rms_at(_wav, v.get_playback_position(), 0.045)
		target = clampf(amp / 0.3, 0.0, 1.0)
	# Smooth toward target so the mouth doesn't strobe. delta is fixed under Movie Maker.
	mouth_open = lerpf(mouth_open, target, clampf(delta * 25.0, 0.0, 1.0))
	var m := _mouth()
	if m and m.has_method("set_open"):
		m.set_open(mouth_open)
