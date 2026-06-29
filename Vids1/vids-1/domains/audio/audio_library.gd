# AudioLibrary - resolves sfx/ambience/music names to AudioStreams (names over paths).
# For now everything is a DETERMINISTIC procedural placeholder so the event system is
# demonstrable without assets; drop real files in later and resolve them here by name.
# (No randf() anywhere - renders must stay byte-identical.)
class_name AudioLibrary
extends RefCounted

const RATE := 22050

# One-shot effects: freq + duration + envelope flags.
const SFX := {
	"pop":    {"freq": 480.0, "dur": 0.09, "decay": true},
	"thud":   {"freq": 90.0,  "dur": 0.16, "decay": true},
	"ding":   {"freq": 880.0, "dur": 0.32, "decay": true},
	"whoosh": {"freq": 200.0, "dur": 0.30, "sweep": 1200.0},
	"moo":    {"freq": 150.0, "dur": 0.55, "decay": true, "vibrato": 6.0},
}

# Scales for the placeholder arpeggio "music" (semitone-ish frequencies).
const MUSIC := {
	"happy": [261.63, 329.63, 392.0, 523.25, 392.0, 329.63],   # C major
	"tense": [220.0, 261.63, 329.63, 440.0, 329.63, 261.63],   # A minor
}

static func sfx(name: String) -> AudioStreamWAV:
	var p: Dictionary = SFX.get(name, {"freq": 440.0, "dur": 0.1, "decay": true})
	var n := int(p.dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var freq: float = p.freq
		if p.has("sweep"):
			freq = lerpf(p.freq, p.sweep, t / p.dur)
		if p.has("vibrato"):
			freq += sin(TAU * p.vibrato * t) * 12.0
		var env := exp(-t * 6.0 / p.dur) if p.get("decay", false) else _window(t, p.dur)
		s[i] = sin(TAU * freq * t) * env * 0.6
	return _build(s, false)

static func ambience(_name: String) -> AudioStreamWAV:
	# Soft low drone (two detuned sines), quiet, seamless 2s loop.
	var n := int(2.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(TAU * 110.0 * t) + 0.6 * sin(TAU * 165.0 * t)) * 0.12
	return _build(s, true)

static func music(name: String) -> AudioStreamWAV:
	var scale: Array = MUSIC.get(name, MUSIC.happy)
	var note_dur := 0.33
	var n := int(scale.size() * note_dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var idx := int(t / note_dur) % scale.size()
		var nt := fmod(t, note_dur)
		var env := _window(nt, note_dur)
		s[i] = sin(TAU * float(scale[idx]) * t) * env * 0.35
	return _build(s, true)

# --- internals ---

static func _window(t: float, dur: float) -> float:
	# 20ms attack/release so notes/effects don't click.
	return clampf(minf(t, dur - t) / 0.02, 0.0, 1.0)

static func _build(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w
