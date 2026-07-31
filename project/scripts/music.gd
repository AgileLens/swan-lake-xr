class_name MusicDirector
extends Node
# PD Swan Lake playback + smoothed loudness envelope + Act 4 finale state.

signal finale_done

# Per-track tempo measured from the actual recordings by tools/measure_tempo.py
# (onset-flux comb fit). v2 used one hardcoded 72 BPM for both, which matched
# neither. Act 4 scored 79.0 unanimously; Act 2's Scène is ambiguous between
# tempo octaves — 59.0 is the quarter-note family both metrics agree on.
# offset = seconds into the file where the beat grid starts.
const TRACKS := {
	"act2": {"bpm": 59.0, "offset": 0.254},
	"act4": {"bpm": 79.0, "offset": 0.237},
}
# How tightly one-shot SFX snap to the beat. Rubato makes true lock impossible,
# so which of these reads best is a taste call — cycled from the orb menu.
const TIMING_MODES := ["eighth", "quarter", "free"]

var energy := 0.0
var timing_mode := 0
var _sfx_queue: Array[Callable] = []
var _next_grid := -1.0
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
	_next_grid = -1.0  # re-latch the grid to act 4's tempo/phase
	_act4.volume_db = -6.0
	_act4.play()
	var tw := create_tween()
	tw.tween_property(_act2, "volume_db", -28.0, 2.0)

func _on_finale_finished() -> void:
	act4_active = false
	_next_grid = -1.0
	var tw := create_tween()
	tw.tween_property(_act2, "volume_db", -6.0, 2.5)
	finale_done.emit()

func timing_mode_name() -> String:
	return TIMING_MODES[timing_mode]

func cycle_timing() -> void:
	timing_mode = (timing_mode + 1) % TIMING_MODES.size()
	_next_grid = -1.0

func _active_track() -> Dictionary:
	return TRACKS["act4"] if act4_active else TRACKS["act2"]

func _playhead() -> float:
	var p: AudioStreamPlayer = _act4 if act4_active else _act2
	return p.get_playback_position() + AudioServer.get_time_since_last_mix()

func beat_seconds() -> float:
	var bpm: float = _active_track()["bpm"]
	return 60.0 / bpm

func beat_phase() -> float:
	# 0..1 across one quarter note, locked to playback position. Drives the corps
	# de ballet's sway so thousands of swans move on the same beat the SFX land on.
	var offset: float = _active_track()["offset"]
	var b := beat_seconds()
	return fposmod(_playhead() - offset, b) / b

func bar_phase() -> float:
	# 0..1 across four beats — slower gestures (a wing lift) want the bar, not the beat
	var offset: float = _active_track()["offset"]
	var bar := beat_seconds() * 4.0
	return fposmod(_playhead() - offset, bar) / bar

func grid_seconds() -> float:
	# NOTE: Dictionary values are untyped, so every read needs an explicit
	# annotation — `:=` inference fails to compile (KB: godot-pico-apk-pipeline #6).
	var bpm: float = _active_track()["bpm"]
	return 60.0 / bpm / (2.0 if timing_mode == 0 else 1.0)

func schedule_sfx(cb: Callable) -> void:
	# quantize one-shot SFX to the next beat subdivision so they land in rhythm
	if timing_mode == 2:  # free — fire immediately, no grid
		cb.call()
		return
	if _sfx_queue.size() < 3:
		_sfx_queue.append(cb)

func _flush_grid() -> void:
	# Grid is derived from the PLAYBACK POSITION, not a free-running accumulator:
	# v2's clock drifted out of phase with the music within a minute.
	var g := grid_seconds()
	var offset: float = _active_track()["offset"]
	var pos: float = _playhead() - offset
	var boundary: float = (floorf(pos / g) + 1.0) * g
	if _next_grid < 0.0:
		_next_grid = boundary
		return
	if pos >= _next_grid:
		for cb in _sfx_queue:
			cb.call()
		_sfx_queue.clear()
		_next_grid = boundary

func _process(delta: float) -> void:
	_flush_grid()
	if _spectrum == null:
		return
	var mag := _spectrum.get_magnitude_for_frequency_range(60.0, 2200.0,
		AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
	var raw := clampf((mag.x + mag.y) * 18.0, 0.0, 1.4)
	energy = lerpf(energy, raw, clampf(delta * 3.5, 0.0, 1.0))
	_peak_avg = lerpf(_peak_avg, energy, clampf(delta * 0.25, 0.0, 1.0))
	swell_flag = energy > _peak_avg * 1.55 and energy > 0.28 and _prev_energy <= _peak_avg * 1.55
	_prev_energy = energy
