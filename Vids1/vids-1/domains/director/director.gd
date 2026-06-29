# Director - parses an episode .md into an EpisodeScript and plays its beats, advancing
# the playhead by each beat's duration (dialogue is the clock; see docs/timeline-spec.md).
# The visual cast comes from hand-editable scenes via CastRegistry.
extends Node

@export_file("*.md") var episode_path: String = "res://episodes/cookie.md"
@export var quit_on_finish := false

## Placeholder-tone pacing, used only when no real voice is available for a line.
const SECS_PER_CHAR := 0.06
const MIN_BEAT := 0.8
const BEAT_GAP := 0.25
const GROUND_Y := 470.0
const DEFAULT_LANGUAGE := "en"   # bottom of the language resolution chain

var _cast := {}
var _episode_language := ""

func _ready() -> void:
	run()

func run() -> void:
	# Spawn after the first frame: adding to Main during _ready() trips Godot's
	# "parent busy setting up children" guard and the nodes never enter the tree.
	await get_tree().process_frame
	var path := _resolve_episode_path()
	var script := ScriptParser.parse_file(path)
	_episode_language = script.language
	Log.info("Playing '%s' (%d beats, lang=%s, tts=%s)" % [
		script.title, script.beats.size(),
		_episode_language if _episode_language else "(default)",
		"on" if Tts.available() else "off (tone)"], "Director")
	_build_cast(script)
	await get_tree().process_frame   # let characters' _ready run

	for i in script.beats.size():
		var beat: Dictionary = script.beats[i]
		match beat.get("type"):
			"say": await _play_say(beat, i)
			"wait": await get_tree().create_timer(beat.seconds).timeout

	_set_subtitle("", "")
	EventBus.episode_finished.emit()
	Log.info("Episode finished", "Director")
	# Quit so Movie Maker finalizes the file. The engine consumes --write-movie before
	# it reaches script args, so render with a user flag after `--` (always preserved).
	if quit_on_finish or "--render" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.5).timeout
		get_tree().quit()

func _play_say(beat: Dictionary, index: int) -> void:
	var c: Character = _cast.get(beat.speaker)
	if c == null:
		Log.warning("No cast member for '%s', skipping line" % beat.speaker, "Director")
		return
	var clip := _clip_for(c, beat)
	_set_subtitle(c.data.display_name, beat.text)
	EventBus.beat_started.emit(index, beat.text)
	c.speak(clip.wav)
	await get_tree().create_timer(clip.dur).timeout   # dialogue is the clock
	c.stop_speaking()
	await get_tree().create_timer(BEAT_GAP).timeout

## Real TTS clip if a voice resolves for the beat's language; else a placeholder tone.
## Returns {wav: AudioStreamWAV, dur: float} - dur drives the playhead.
func _clip_for(c: Character, beat: Dictionary) -> Dictionary:
	var lang := _resolve_language(beat, c)
	var model: String = c.data.voice_for(lang)
	if model != "":
		var wav := Tts.synth(beat.text, model)
		if wav != null:
			return {"wav": wav, "dur": _wav_seconds(wav)}
		Log.warning("TTS failed for voice '%s', using tone" % model, "Director")
	var dur := maxf(MIN_BEAT, SECS_PER_CHAR * beat.text.length())
	return {"wav": Tone.speech_like(dur, 140.0 * c.data.voice_pitch), "dur": dur}

## Language for a line, most specific first: @lang -> character -> episode -> default.
func _resolve_language(beat: Dictionary, c: Character) -> String:
	if beat.get("lang", "") != "":
		return beat.lang
	if c.data.language != "":
		return c.data.language
	if _episode_language != "":
		return _episode_language
	return DEFAULT_LANGUAGE

func _wav_seconds(wav: AudioStreamWAV) -> float:
	return (wav.data.size() / 2) / float(wav.mix_rate)   # 16-bit mono

func _build_cast(script: EpisodeScript) -> void:
	# Spawn each speaking character once, spread evenly across the stage in first-seen order.
	var ids := []
	for beat in script.beats:
		if beat.get("type") == "say" and not ids.has(beat.speaker):
			ids.append(beat.speaker)
	var xs := _spread(ids.size())
	for idx in ids.size():
		_spawn(ids[idx], Vector2(xs[idx], GROUND_Y))

func _spawn(id: String, pos: Vector2) -> void:
	var c := CastRegistry.create(id)
	if c == null:
		Log.error("Unknown cast id: " + id, "Director")
		return
	c.position = pos
	add_sibling(c, true)   # sibling of Director -> child of Main, drawn above the ground
	_cast[id] = c

## Evenly spaced x positions across the stage for n characters.
func _spread(n: int) -> Array:
	if n <= 1:
		return [640.0]
	var left := 380.0
	var right := 900.0
	var out := []
	for i in n:
		out.append(left + (right - left) * float(i) / float(n - 1))
	return out

## Episode to play: the exported default, overridable at render time with
## `-- --episode res://episodes/<name>.md` (no code edit needed).
func _resolve_episode_path() -> String:
	var uargs := OS.get_cmdline_user_args()
	var i := uargs.find("--episode")
	if i != -1 and i + 1 < uargs.size():
		return uargs[i + 1]
	return episode_path

func _set_subtitle(speaker: String, text: String) -> void:
	var label := get_node_or_null("%Subtitle") as Label
	if label:
		label.text = "%s:  %s" % [speaker, text] if text != "" else ""
