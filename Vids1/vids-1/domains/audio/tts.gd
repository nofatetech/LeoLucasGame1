# Tts - local, offline text-to-speech via Piper. Deterministic (same text+voice -> same
# audio), so renders stay reproducible. Outputs 16-bit mono PCM -> AudioStreamWAV, the same
# format Tone/ClipAmplitude use, so the mouth-flap lip-syncs to real speech for free.
#
# Setup (not committed - large binaries live outside the repo):
#   ~/Apps/piper/piper                      (binary, from rhasspy/piper releases)
#   ~/Apps/piper/voices/<model>.onnx(.json) (voice models, from rhasspy/piper-voices)
# Override the binary path with the VIDS_PIPER_BIN env var.
class_name Tts
extends RefCounted

const DEFAULT_RATE := 22050

static func available() -> bool:
	return FileAccess.file_exists(_piper_bin())

static func has_voice(model: String) -> bool:
	return model != "" and FileAccess.file_exists(_model_path(model))

## Synthesize text in the given voice model. Returns a 16-bit mono AudioStreamWAV,
## or null if Piper / the voice is unavailable or synthesis fails (caller falls back).
static func synth(text: String, model: String) -> AudioStreamWAV:
	if not available() or not has_voice(model):
		return null
	var rate := _model_rate(model)
	var cache := _cache_path(text, model)
	if not FileAccess.file_exists(cache):
		if not _run(text, model, cache):
			return null
	return _wav_from_raw(cache, rate)

# --- internals ---

static func _piper_dir() -> String:
	return OS.get_environment("HOME") + "/Apps/piper"

static func _piper_bin() -> String:
	var env := OS.get_environment("VIDS_PIPER_BIN")
	return env if env != "" else _piper_dir() + "/piper"

static func _model_path(model: String) -> String:
	return _piper_dir() + "/voices/" + model + ".onnx"

static func _cache_dir() -> String:
	var d := OS.get_user_data_dir() + "/tts_cache"
	DirAccess.make_dir_recursive_absolute(d)
	return d

static func _cache_path(text: String, model: String) -> String:
	return "%s/%s_%s.raw" % [_cache_dir(), model, text.sha256_text().substr(0, 16)]

static func _model_rate(model: String) -> int:
	var jpath := _model_path(model) + ".json"
	if FileAccess.file_exists(jpath):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(jpath))
		if data is Dictionary and data.has("audio") and data.audio.has("sample_rate"):
			return int(data.audio.sample_rate)
	return DEFAULT_RATE

static func _run(text: String, model: String, out_raw: String) -> bool:
	var infile := _cache_dir() + "/_in.txt"
	var f := FileAccess.open(infile, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	# cd into the piper dir so it resolves its libs ($ORIGIN rpath) and espeak-ng-data.
	var cmd := "cd '%s' && ./piper -m '%s' --output-raw < '%s' > '%s'" % [
		_piper_dir(), _model_path(model), infile, out_raw]
	var output := []
	var code := OS.execute("bash", ["-lc", cmd], output, true)
	if code != 0:
		push_error("piper failed (%d): %s" % [code, "\n".join(output)])
		return false
	return FileAccess.file_exists(out_raw)

static func _wav_from_raw(path: String, rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = FileAccess.get_file_as_bytes(path)
	return wav
