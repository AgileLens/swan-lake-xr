class_name MusicDirector
extends Node
# PD Swan Lake playback + smoothed loudness envelope + Act 4 finale state.

signal finale_done

const BPM := 72.0
const GRID := 60.0 / BPM / 2.0  # eighth notes

var energy := 0.0
var _grid_clock := 0.0
var _sfx_queue: Array[Callable] = []
var swell_flag := false
var act4_active := false
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _act2: AudioStreamPlayer
var _act4: AudioStreamPlayer
var _peak_avg := 0.0
var _prev_energy := 0.0

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
	_act4.finished.connect(_on_finale_finished)

func play_finale() -> void:
	if act4_active:
		return
	act4_active = true
	_act4.volume_db = -6.0
	_act4.play()
	var tw := create_tween()
	tw.tween_property(_act2, "volume_db", -28.0, 2.0)

func _on_finale_finished() -> void:
	act4_active = false
	var tw := create_tween()
	tw.tween_property(_act2, "volume_db", -6.0, 2.5)
	finale_done.emit()

func schedule_sfx(cb: Callable) -> void:
	# quantize one-shot SFX to the next eighth-note so they land in rhythm
	if _sfx_queue.size() < 3:
		_sfx_queue.append(cb)

func _process(delta: float) -> void:
	_grid_clock += delta
	if _grid_clock >= GRID:
		_grid_clock = fmod(_grid_clock, GRID)
		for cb in _sfx_queue:
			cb.call()
		_sfx_queue.clear()
	if _spectrum == null:
		return
	var mag := _spectrum.get_magnitude_for_frequency_range(60.0, 2200.0,
		AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
	var raw := clampf((mag.x + mag.y) * 18.0, 0.0, 1.4)
	energy = lerpf(energy, raw, clampf(delta * 3.5, 0.0, 1.0))
	_peak_avg = lerpf(_peak_avg, energy, clampf(delta * 0.25, 0.0, 1.0))
	swell_flag = energy > _peak_avg * 1.55 and energy > 0.28 and _prev_energy <= _peak_avg * 1.55
	_prev_energy = energy
