extends Node
class_name AudioSynthesizer
## Procedural Audio Synthesizer — Generates lightweight procedural AudioStreamWAV sounds in-memory.
## Ensures the game has real tactile audio feedback without external audio asset bloat.

static func create_gunshot(sample_rate: int = 22050, duration: float = 0.25) -> AudioStreamWAV:
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)
	
	for i in num_samples:
		var t := float(i) / float(sample_rate)
		var envelope := exp(-t * 22.0)
		var noise := randf_range(-1.0, 1.0)
		var punch := sin(t * 180.0 * TAU) * exp(-t * 35.0) * 0.8
		var sample := clampf((noise * 0.7 + punch * 0.3) * envelope, -1.0, 1.0)
		data[i] = int((sample + 1.0) * 127.5)
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


static func create_reload_click(sample_rate: int = 22050, duration: float = 0.15) -> AudioStreamWAV:
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)
	
	for i in num_samples:
		var t := float(i) / float(sample_rate)
		var click1 := sin(t * 800.0 * TAU) * exp(-t * 70.0)
		var click2 := sin((t - 0.06) * 1200.0 * TAU) * exp(-(t - 0.06) * 80.0) if t > 0.06 else 0.0
		var sample := clampf(click1 + click2, -1.0, 1.0)
		data[i] = int((sample + 1.0) * 127.5)
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


static func create_chime(sample_rate: int = 22050, duration: float = 0.4) -> AudioStreamWAV:
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)
	
	for i in num_samples:
		var t := float(i) / float(sample_rate)
		var note1 := sin(t * 523.25 * TAU) * exp(-t * 6.0)  # C5
		var note2 := sin((t - 0.1) * 659.25 * TAU) * exp(-(t - 0.1) * 5.0) if t > 0.1 else 0.0 # E5
		var sample := clampf((note1 * 0.5 + note2 * 0.5), -1.0, 1.0)
		data[i] = int((sample + 1.0) * 127.5)
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream


static func create_hit_blip(sample_rate: int = 22050, duration: float = 0.08) -> AudioStreamWAV:
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)
	
	for i in num_samples:
		var t := float(i) / float(sample_rate)
		var tone := sin(t * 1100.0 * TAU) * exp(-t * 40.0)
		var sample := clampf(tone, -1.0, 1.0)
		data[i] = int((sample + 1.0) * 127.5)
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
