class_name SfxPool
extends Node
# Pooled one-shot SFX (3D + 2D) and crossfading weather loops.

var streams := {}
var pool3d: Array[AudioStreamPlayer3D] = []
var pool2d: Array[AudioStreamPlayer] = []
var loop_a: AudioStreamPlayer
var loop_b: AudioStreamPlayer
var cur_loop := ""

func _ready() -> void:
	for n in ["plop_1","plop_2","plop_3","plop_4","splash","whoosh","crackle","hatch_chord",
			"chime_1","chime_2","chime_3","chime_4","chime_5","chime_6","chime_7",
			"harp_1","harp_2","harp_3","harp_4","harp_5","harp_6","harp_7","harp_8",
			"harp_low_1","harp_low_2","harp_low_3","harp_low_4",
			"wind_loop","rain_loop"]:
		streams[n] = load("res://assets/sfx/%s.wav" % n)
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 60.0
		p.unit_size = 6.0
		add_child(p)
		pool3d.append(p)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool2d.append(p)
	loop_a = AudioStreamPlayer.new(); add_child(loop_a)
	loop_b = AudioStreamPlayer.new(); add_child(loop_b)

func play3d(name: String, pos: Vector3, vol_db := 0.0, pitch_jitter := 0.0) -> void:
	for p in pool3d:
		if not p.playing:
			p.stream = streams[name]
			p.global_position = pos
			p.volume_db = vol_db
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return

func plop(pos: Vector3, strength := 1.0) -> void:
	# samples are pre-tuned to B-minor chord tones; octave doublings stay in key
	var pitch: float = [0.5, 1.0, 1.0, 2.0][randi() % 4]
	for p in pool3d:
		if not p.playing:
			p.stream = streams["plop_%d" % (randi() % 4 + 1)]
			p.global_position = pos
			p.volume_db = linear_to_db(clampf(0.30 + strength * 0.55, 0.1, 0.9))
			p.pitch_scale = pitch
			p.play()
			return

const HARP_DEGREES := 8
const HARP_LOW_DEGREES := 4

func harp(pos: Vector3, degree: int, vol_db := -9.0) -> void:
	# Plucked B-minor scale tone, tuned to within a cent (assets_src/make_sfx.py).
	# Never pitch-shifted at runtime: a shifted pluck detunes against the orchestra,
	# which is the whole thing this replaced.
	play3d("harp_%d" % (posmod(degree, HARP_DEGREES) + 1), pos, vol_db)

func harp_low(pos: Vector3, degree: int, vol_db := -15.0) -> void:
	play3d("harp_low_%d" % (posmod(degree, HARP_LOW_DEGREES) + 1), pos, vol_db)

func play2d(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	for p in pool2d:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return

func set_weather_loop(name: String, vol_db := -14.0) -> void:
	if name == cur_loop:
		return
	cur_loop = name
	var fade_out := loop_a if loop_a.playing else null
	if name != "":
		loop_b.stream = streams[name]
		if loop_b.stream is AudioStreamWAV:
			loop_b.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop_b.stream.loop_end = loop_b.stream.data.size() / 2
		loop_b.volume_db = -50.0
		loop_b.play()
		create_tween().tween_property(loop_b, "volume_db", vol_db, 2.0)
	if fade_out:
		var tw := create_tween()
		tw.tween_property(fade_out, "volume_db", -50.0, 2.0)
		tw.tween_callback(fade_out.stop)
	var tmp := loop_a; loop_a = loop_b; loop_b = tmp
