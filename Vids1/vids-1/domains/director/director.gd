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

## Music mixing: base level, and how far to duck while someone is speaking.
const MUSIC_DB := -8.0
const MUSIC_DUCK_DB := -20.0
const AMBIENCE_DB := -16.0

var _cast := {}
var _episode_language := ""
var _fallback_language := ""   # show/season default, passed by the Studio dock via --language
var _spans := {}   # "music"/"ambience" name -> AudioStreamPlayer (active spans)

# Mood state (set per scene; defaults = neutral).
var _episode_mood := ""
var _fallback_mood := ""       # show/season default, passed via --mood
var _scene_seen := "<init>"   # sentinel so the first beat always applies a mood
var _pace := 1.0
var _voice_length := 1.0
var _voice_noise := 0.667
var _default_bg := Color(0.53, 0.81, 0.92)

func _ready() -> void:
	run()

func run() -> void:
	# Spawn after the first frame: adding to Main during _ready() trips Godot's
	# "parent busy setting up children" guard and the nodes never enter the tree.
	await get_tree().process_frame
	var path := _resolve_episode_path()
	_fallback_language = _cmdline_value("--language")
	_fallback_mood = _cmdline_value("--mood")
	var bg := _background()
	if bg:
		_default_bg = bg.color
	var script := ScriptParser.parse_file(path)
	_episode_language = script.language
	_episode_mood = script.mood
	Log.info("Playing '%s' (%d beats, lang=%s, tts=%s)" % [
		script.title, script.beats.size(),
		_episode_language if _episode_language else "(default)",
		"on" if Tts.available() else "off (tone)"], "Director")
	_build_cast(script)
	await get_tree().process_frame   # let characters' _ready run

	for i in script.beats.size():
		var beat: Dictionary = script.beats[i]
		_maybe_apply_mood(beat)
		match beat.get("type"):
			"say": await _play_say(beat, i)
			"wait": await get_tree().create_timer(beat.seconds).timeout
			"sfx", "ambience", "music": _fire_event(beat)   # Points/Spans: never block the clock

	_stop_all_spans()
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
	# Directives attached to this line fire at its start (sfx offsets are relative to here).
	for ev in beat.get("directives", []):
		_fire_event(ev)
	var clip := _clip_for(c, beat)
	_set_subtitle(c.data.display_name, beat.text)
	EventBus.beat_started.emit(index, beat.text)
	_duck_music(MUSIC_DUCK_DB, 0.12)
	c.speak(clip.wav)
	await get_tree().create_timer(clip.dur).timeout   # dialogue is the clock
	c.stop_speaking()
	_duck_music(MUSIC_DB, 0.2)
	await get_tree().create_timer(BEAT_GAP * _pace).timeout   # mood pacing

## Real TTS clip if a voice resolves for the beat's language; else a placeholder tone.
## Returns {wav: AudioStreamWAV, dur: float} - dur drives the playhead.
func _clip_for(c: Character, beat: Dictionary) -> Dictionary:
	var lang := _resolve_language(beat, c)
	var model: String = c.data.voice_for(lang)
	if model != "":
		var wav := Tts.synth(beat.text, model, _voice_length, _voice_noise)
		if wav != null:
			return {"wav": wav, "dur": _wav_seconds(wav)}
		Log.warning("TTS failed for voice '%s', using tone" % model, "Director")
	var dur := maxf(MIN_BEAT, SECS_PER_CHAR * beat.text.length()) * _voice_length
	return {"wav": Tone.speech_like(dur, 140.0 * c.data.voice_pitch), "dur": dur}

## Language for a line, most specific first:
## @lang -> character -> episode (.md) -> show/season (--language) -> hard default.
func _resolve_language(beat: Dictionary, c: Character) -> String:
	if beat.get("lang", "") != "":
		return beat.lang
	if c.data.language != "":
		return c.data.language
	if _episode_language != "":
		return _episode_language
	if _fallback_language != "":
		return _fallback_language
	return DEFAULT_LANGUAGE

func _wav_seconds(wav: AudioStreamWAV) -> float:
	return (wav.data.size() / 2) / float(wav.mix_rate)   # 16-bit mono

# --- mood (per-scene preset: bg tint + pace + voice delivery) ---

func _maybe_apply_mood(beat: Dictionary) -> void:
	var scene := str(beat.get("scene", ""))
	if scene == _scene_seen:
		return
	_scene_seen = scene
	_apply_mood(_resolve_mood_name(str(beat.get("scene_mood", ""))))

## Mood name, most specific first: scene {mood} -> episode mood: -> --mood -> none.
func _resolve_mood_name(scene_mood: String) -> String:
	if scene_mood != "":
		return scene_mood
	if _episode_mood != "":
		return _episode_mood
	return _fallback_mood

func _apply_mood(name: String) -> void:
	var m := MoodLibrary.get_mood(name)
	if m:
		_pace = m.pace
		_voice_length = m.voice_length_scale
		_voice_noise = m.voice_noise_scale
		_set_bg(m.bg_color if m.has_bg() else _default_bg)
		Log.info("Mood: %s" % name, "Director")
	else:
		_pace = 1.0
		_voice_length = 1.0
		_voice_noise = 0.667
		_set_bg(_default_bg)

func _set_bg(color: Color) -> void:
	var bg := _background()
	if bg:
		create_tween().tween_property(bg, "color", color, 0.4)

func _background() -> ColorRect:
	return get_parent().get_node_or_null("Background") as ColorRect

# --- audio events (Point: sfx; Span: ambience/music) ---

func _fire_event(ev: Dictionary) -> void:
	match ev.type:
		"sfx": _schedule_sfx(ev.name, ev.get("offset", 0.0))
		"ambience": _span("ambience", ev)
		"music": _span("music", ev)

## Play a one-shot, optionally `offset` seconds later. Async, intentionally not awaited.
func _schedule_sfx(name: String, offset: float) -> void:
	if offset > 0.0:
		await get_tree().create_timer(offset).timeout
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = AudioLibrary.sfx(name)
	p.finished.connect(p.queue_free)
	p.play()

func _span(kind: String, ev: Dictionary) -> void:
	var name: String = ev.name
	var prefix := kind + ":"
	if ev.get("action", "start") == "stop":
		# Empty name stops every span of this kind (e.g. "[music: stop]").
		for key in _spans.keys():
			if key.begins_with(prefix) and (name == "" or key == prefix + name):
				_spans[key].queue_free()
				_spans.erase(key)
		return
	var key := prefix + name
	if _spans.has(key):
		return
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = AudioLibrary.music(name) if kind == "music" else AudioLibrary.ambience(name)
	p.volume_db = MUSIC_DB if kind == "music" else AMBIENCE_DB
	p.play()
	_spans[key] = p

func _duck_music(db: float, dur: float) -> void:
	for key in _spans:
		if key.begins_with("music:"):
			create_tween().tween_property(_spans[key], "volume_db", db, dur)

func _stop_all_spans() -> void:
	for p in _spans.values():
		p.queue_free()
	_spans.clear()

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
	var override := _cmdline_value("--episode")
	return override if override != "" else episode_path

## Value following a user-arg flag (after `--`), or "" if absent.
func _cmdline_value(flag: String) -> String:
	var uargs := OS.get_cmdline_user_args()
	var i := uargs.find(flag)
	return uargs[i + 1] if i != -1 and i + 1 < uargs.size() else ""

func _set_subtitle(speaker: String, text: String) -> void:
	var label := get_node_or_null("%Subtitle") as Label
	if label:
		label.text = "%s:  %s" % [speaker, text] if text != "" else ""
