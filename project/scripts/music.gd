class_name MusicDirector
extends Node
# Plays the program's recordings and answers "where are we in the music?" for everything else.
#
# Every clip ships with a baked beat map and loudness envelope (tools/make_program_audio.py).
# Choreography, conducting scores and the SFX grid read those instead of a live spectrum
# analyzer. That costs nothing on the audio thread, gives the same answer every run, and
# lets --autotest run a 25 minute program on a virtual clock in seconds.

signal finale_done
signal clip_finished(clip_id: String)

const SWELL_RATIO := 1.45
const TIMING_MODES := ["eighth", "quarter", "free"]

var energy := 0.0
var timing_mode := 0
var swell_flag := false
var act4_active := false  # true during the fireworks finale; megaflock and fireworks read it
var key_ratio := 1.0      # SFX transposition into the current clip's key
var virtual_clock := false  # --autotest: time passes without decoding audio
var clip_id := ""
var clip := {}            # the baked data of the current clip
var _beats := PackedFloat32Array()
var _env := PackedFloat32Array()
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _virtual_pos := 0.0
var _peak_avg := 0.0
var _prev_energy := 0.0
var _sfx_queue: Array[Callable] = []
var _next_grid := -1.0
var _loop := false
var _ended := false
var _cache := {}

func _ready() -> void:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Music")
	AudioServer.set_bus_send(idx, "Master")
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	for p in [_player_a, _player_b]:
		p.bus = "Music"
		p.volume_db = -60.0
		add_child(p)
	_active = _player_a

static func load_clip_data(id: String) -> Dictionary:
	var f := FileAccess.open("res://assets/music/%s.json" % id, FileAccess.READ)
	if f == null:
		push_error("[music] missing beat map for clip '%s'" % id)
		return {}
	return JSON.parse_string(f.get_as_text())

func play_clip(id: String, fade := 1.2, from := 0.0, loop := false) -> void:
	clip_id = id
	if not _cache.has(id):
		_cache[id] = load_clip_data(id)
	clip = _cache[id]
	_beats = PackedFloat32Array(clip.get("beats", []))
	_env = PackedFloat32Array(clip.get("env", []))
	key_ratio = float(clip.get("key_ratio", 1.0))
	_loop = loop
	_ended = false
	_next_grid = -1.0
	_virtual_pos = from
	if virtual_clock:
		return
	var old := _active
	_active = _player_b if old == _player_a else _player_a
	var stream: AudioStream = load("res://assets/music/%s.mp3" % id)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	_active.stream = stream
	_active.volume_db = -40.0 if fade > 0.0 else -2.0
	_active.play(from)
	if fade > 0.0:
		var tw := create_tween()
		tw.tween_property(_active, "volume_db", -2.0, fade)
	if old.playing:
		var tw2 := create_tween()
		tw2.tween_property(old, "volume_db", -50.0, maxf(fade, 0.2))
		tw2.tween_callback(old.stop)

func stop_music(fade := 1.5) -> void:
	clip_id = ""
	_ended = true
	if virtual_clock or not _active.playing:
		return
	var p := _active
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -50.0, fade)
	tw.tween_callback(p.stop)

func duration() -> float:
	return float(clip.get("duration", 0.0))

func playhead() -> float:
	if virtual_clock:
		return _virtual_pos
	if _active == null or not _active.playing:
		return _virtual_pos
	_virtual_pos = _active.get_playback_position() + AudioServer.get_time_since_last_mix()
	return _virtual_pos

# ---------------------------------------------------------------- beat map

func beat_index(t: float) -> int:
	# Index of the last beat at or before t, or -1 before the first.
	return _beats.bsearch(t, false) - 1

func beat_seconds() -> float:
	if _beats.size() < 2:
		return 1.0
	var i := clampi(beat_index(playhead()), 0, _beats.size() - 2)
	return maxf(_beats[i + 1] - _beats[i], 0.2)

func beat_phase() -> float:
	if _beats.size() < 2:
		return fposmod(playhead(), 1.0)
	var t := playhead()
	var i := clampi(beat_index(t), 0, _beats.size() - 2)
	return clampf((t - _beats[i]) / maxf(_beats[i + 1] - _beats[i], 0.01), 0.0, 1.0)

func bar_phase() -> float:
	# Four beats to the bar. A barline is not known for every piece, so this is only a slow
	# clock for gestures, never something a user is judged against.
	var i := maxi(beat_index(playhead()), 0)
	return (float(i % 4) + beat_phase()) / 4.0

func nearest_beat_error(t: float) -> float:
	# Absolute distance to the nearest beat, as a fraction of one beat (0 .. 0.5).
	if _beats.size() < 2:
		return 0.5
	var i := clampi(beat_index(t), 0, _beats.size() - 2)
	var span := maxf(_beats[i + 1] - _beats[i], 0.01)
	return minf(absf(t - _beats[i]), absf(_beats[i + 1] - t)) / span

func env_at(t: float) -> float:
	if _env.is_empty():
		return 0.0
	var x := t * float(clip.get("env_rate", 10))
	var i := clampi(int(x), 0, _env.size() - 1)
	var j := mini(i + 1, _env.size() - 1)
	return lerpf(_env[i], _env[j], clampf(x - float(i), 0.0, 1.0))

# ---------------------------------------------------------------- SFX on the grid

func timing_mode_name() -> String:
	return TIMING_MODES[timing_mode]

func cycle_timing() -> void:
	timing_mode = (timing_mode + 1) % TIMING_MODES.size()
	_next_grid = -1.0

func grid_seconds() -> float:
	return beat_seconds() / (2.0 if timing_mode == 0 else 1.0)

func schedule_sfx(cb: Callable) -> void:
	# Quantize one-shot SFX to the next subdivision, so they land in rhythm with the recording.
	if timing_mode == 2 or clip_id == "":
		cb.call()
		return
	if _sfx_queue.size() < 3:
		_sfx_queue.append(cb)

func _flush_grid() -> void:
	var g := grid_seconds()
	var pos := playhead()
	var i := clampi(beat_index(pos), 0, maxi(_beats.size() - 1, 0))
	var base: float = _beats[i] if not _beats.is_empty() else 0.0
	var boundary: float = base + (floorf((pos - base) / g) + 1.0) * g
	if _next_grid < 0.0:
		_next_grid = boundary
		return
	if pos >= _next_grid:
		for cb in _sfx_queue:
			cb.call()
		_sfx_queue.clear()
		_next_grid = boundary

func tick_virtual(delta: float) -> void:
	_virtual_pos += delta

func _process(delta: float) -> void:
	if virtual_clock and clip_id != "":
		_virtual_pos += delta
	var t := playhead()
	if clip_id != "":
		_flush_grid()
	var raw := env_at(t) if clip_id != "" else 0.0
	energy = lerpf(energy, raw, clampf(delta * 3.5, 0.0, 1.0))
	_peak_avg = lerpf(_peak_avg, energy, clampf(delta * 0.25, 0.0, 1.0))
	swell_flag = energy > _peak_avg * SWELL_RATIO and energy > 0.28 and _prev_energy <= _peak_avg * SWELL_RATIO
	_prev_energy = energy
	if clip_id != "" and not _ended and not _loop and t >= duration() - 0.03:
		_ended = true
		clip_finished.emit(clip_id)
