# ClipAmplitude - reads RMS amplitude from a 16-bit mono clip at a playback position.
# Deterministic (samples the PCM directly), so mouth-flap is identical on re-render.
class_name ClipAmplitude
extends RefCounted

## RMS of the samples in a +/- (window/2) seconds window centered on pos_sec. 0..1.
static func rms_at(wav: AudioStreamWAV, pos_sec: float, window: float) -> float:
	if wav == null:
		return 0.0
	var rate := wav.mix_rate
	var data := wav.data
	var sample_count := data.size() / 2          # 16-bit mono => 2 bytes/sample
	var center := int(pos_sec * rate)
	var half := int(window * rate * 0.5)
	var start := maxi(center - half, 0)
	var end := mini(center + half, sample_count)
	if end <= start:
		return 0.0
	var sum := 0.0
	var i := start
	while i < end:
		var f := data.decode_s16(i * 2) / 32768.0
		sum += f * f
		i += 1
	return sqrt(sum / float(end - start))
