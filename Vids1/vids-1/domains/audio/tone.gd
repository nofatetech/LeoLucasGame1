# Tone - generates placeholder "speech-like" audio clips for M0.
# A carrier sine modulated by a ~4 Hz syllable envelope, so amplitude varies and
# the mouth flaps convincingly. Replaced by real TTS in M2 - same AudioStreamWAV out.
class_name Tone
extends RefCounted

const RATE := 22050

## Returns a mono 16-bit clip of the given duration whose amplitude pulses like speech.
static func speech_like(duration: float, freq: float) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var carrier := sin(TAU * freq * t)
		var syllable := 0.5 * (1.0 - cos(TAU * 4.0 * t))         # 0..1, ~4 per second
		var fade := clampf(minf(t, duration - t) / 0.05, 0.0, 1.0) # 50ms edges
		var v := carrier * syllable * fade * 0.5
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
