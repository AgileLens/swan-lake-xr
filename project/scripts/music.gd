class_name MusicDirector
extends Node
# Plays the PD Swan Lake recordings, exposes a smoothed loudness envelope.

var energy := 0.0        # 0..~1 smoothed
var swell_flag := false  # one-shot: big swell just started
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _act2: AudioStreamPlayer
var _act4: AudioStreamPlayer
var _peak_avg := 0.0
var _prev_energy := 0.0
var _finale_playing := false

func _ready() -> void:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Music")
	AudioServer.set_bus_send(idx, "Master")
	var fx := AudioEffectSpectrumAnalyzer.new()
	fx.buffer_length = 0.1
	AudioServer.add_bus_effect(idx, fx)
	_spectrum = AudioServer.get_bus_effect_instance(idx, 0)
	_act2 = AudioStreamPlayer.new()
	_act2.stream = load("res://assets/music/act2_scene.ogg")
	if _act2.stream is AudioStreamOggVorbis:
		_act2.stream.loop = true
	_act2.bus = "Music"
	_act2.volume_db = -6.0
	add_child(_act2)
	_act4 = AudioStreamPlayer.new()
	_act4.stream = load("res://assets/music/act4.ogg")
	_act4.bus = "Music"
	_act4.volume_db = -60.0
	add_child(_act4)
	_act2.play()
	_act4.finished.connect(_on_finale_done)

func play_finale() -> void:
	if _finale_playing:
		return
	_finale_playing = true
	_act4.volume_db = -6.0
	_act4.play()
	var tw := create_tween()
	tw.tween_property(_act2, "volume_db", -28.0, 2.0)

func _on_finale_done() -> void:
	_finale_playing = false
	var tw := create_tween()
	tw.tween_property(_act2, "volume_db", -6.0, 2.5)

func _process(delta: float) -> void:
	if _spectrum == null:
		return
	var mag := _spectrum.get_magnitude_for_frequency_range(60.0, 2200.0,
		AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
	var raw := clampf((mag.x + mag.y) * 18.0, 0.0, 1.4)
	energy = lerpf(energy, raw, clampf(delta * 3.5, 0.0, 1.0))
	# adaptive swell detection: energy pops well above its slow average
	_peak_avg = lerpf(_peak_avg, energy, clampf(delta * 0.25, 0.0, 1.0))
	if energy > _peak_avg * 1.55 and energy > 0.28 and _prev_energy <= _peak_avg * 1.55:
		swell_flag = true
	_prev_energy = energy
