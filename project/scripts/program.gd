class_name ConductorsProgram
extends Node
# The Conductor's Program: walks the running order, stages each movement, watches the baton,
# and has the flock react. The program never waits on the player. If nobody lifts a finger, it
# plays start to finish and still ends with a bow.

signal movement_started(index: int)
signal movement_ended(index: int, grade: float)
signal program_finished(grace: float, tier: int)

enum State { IDLE, ANNOUNCE, PLAY, BOW, CURTAIN, FREE }

const ANNOUNCE_TIME := 3.0
const BOW_TIME := 3.5
const HIGH_BATON := 0.12     # above the eyes minus this much counts as raised, in meters
const WAKE_INTERVAL := 12.0  # the flock wakes by itself at this pace, whatever you do

var main  # SwanLakeMain
var state := State.IDLE
var index := -1
var movement := {}
var score: ConductLogic.MovementScore
var grades: Array = []
var _state_t := 0.0
var _cue_i := 0
var _ictus := ConductLogic.IctusDetector.new()
var _size := ConductLogic.GestureSize.new()
var _prev_tip := Vector3.ZERO
var _tip_speed := 0.0
var _wake_t := 0.0
var _woken := 0
var _lead_point := Vector3(0, 0, -7)
var _lead_auto_t := 0.0
var _accents := PackedFloat32Array()
var _accent_i := 0
var _last_strike_t := -10.0
var _paint_bins := PackedByteArray()
var _gather_auto := false
var _idle_t := 0.0
var _swell_cool := 0.0
var _encore_used := false
var _smooth_time := 0.0
var _last_on_beat_t := -10.0
var grace := ConductLogic.GRADE_FLOOR
var tier := 0
var last_ictus_on_beat := false
var ictus_count := 0
var on_beat_count := 0
var flock_warmth := 0.3  # 0..1, what the swans currently show back to you

func setup(m) -> void:
	main = m
	main.music.clip_finished.connect(_on_clip_finished)

func start(from_index := 0) -> void:
	grades.clear()
	_begin(from_index)

func current_title() -> String:
	return str(movement.get("title", ""))

func is_playing() -> bool:
	return state == State.PLAY or state == State.ANNOUNCE or state == State.BOW

func _begin(i: int) -> void:
	index = i
	movement = ProgramData.MOVEMENTS[i]
	state = State.ANNOUNCE
	_state_t = 0.0
	_cue_i = 0
	var data := MusicDirector.load_clip_data(movement["clip"])
	score = ConductLogic.MovementScore.new(float(data.get("duration", 60.0)))
	_stage_movement()
	main.stand.show_movement(i)
	main.title.movement_card(movement)
	movement_started.emit(i)
	print("[program] ", movement["id"], " ", movement["title"], " (", snappedf(float(data.get("duration", 0.0)), 0.1), " s)")

func _stage_movement() -> void:
	main.flock.set_formation(movement["formation"])
	main.rainbow.set_target(0.0)
	_gather_auto = false
	main.set_gather(false)
	_paint_bins = PackedByteArray(); _paint_bins.resize(14)
	_accents = PackedFloat32Array()
	_accent_i = 0
	_smooth_time = 0.0
	if movement["verb"] == "strike":
		_accents = _find_accents(MusicDirector.load_clip_data(movement["clip"]))
	if movement["id"] == "prelude":
		main.flock.put_to_sleep()
	if movement["verb"] == "stars":
		main.constellation.set_prominent(true)
	else:
		main.constellation.set_prominent(false)

static func _find_accents(data: Dictionary) -> PackedFloat32Array:
	# Crashes in the storm: sharp rises in the loudness envelope.
	var out := PackedFloat32Array()
	var env: Array = data.get("env", [])
	var rate := float(data.get("env_rate", 10))
	var last := -10.0
	for i in range(5, env.size()):
		var rise := float(env[i]) - float(env[i - 5])
		var t := float(i) / rate
		if rise > 0.22 and float(env[i]) > 0.5 and t - last > 2.8:
			out.append(t)
			last = t
	return out

func next_movement() -> void:
	# Skip forward: the player's choice, so no judgment beyond what they already earned.
	if state == State.FREE:
		encore()
		return
	if state == State.CURTAIN:
		_to_free()
		return
	_finish_movement()

func encore() -> void:
	# After the curtain the finale can be played again, as many times as you like.
	state = State.IDLE
	main.flock.set_formation("free")
	_begin(ProgramData.index_of("finale"))
	_encore_used = true

func restart() -> void:
	main.flock.set_formation("free")
	start(0)

func _finish_movement() -> void:
	if state == State.BOW:
		_state_t = BOW_TIME
		return
	var g: float = score.grade() if score else ConductLogic.GRADE_FLOOR
	if not _encore_used:
		grades.append(g)
	movement_ended.emit(index, g)
	main.stand.rosette(index, g)
	state = State.BOW
	_state_t = 0.0
	main.flock.react(g)
	main.fireflies.celebrate()
	if movement["verb"] != "launch":
		main.music.stop_music(2.0)
	print("[program] ", movement["id"], " grade ", snappedf(g, 0.01))

func _on_clip_finished(id: String) -> void:
	if state == State.PLAY and movement.get("clip", "") == id:
		_finish_movement()

func _to_curtain() -> void:
	state = State.CURTAIN
	_state_t = 0.0
	grace = ConductLogic.overall(grades)
	tier = ConductLogic.tier_for(grace)
	var t: Dictionary = ConductLogic.TIERS[tier]
	main.flock.set_formation("curtain")
	main.flock.curtain_call(float(t["salute"]))
	main.fireworks.start_curtain(int(t["barrage"]))
	main.feathers.start(tier)
	main.megaflock.ovation(float(t["salute"]))
	main.stand.show_curtain(t, grace)
	main.title.curtain_card(t)
	program_finished.emit(grace, tier)
	print("[program] curtain grace=", snappedf(grace, 0.01), " tier=", tier, " ", t["name"])

func _to_free() -> void:
	state = State.FREE
	_state_t = 0.0
	main.flock.set_formation("free")
	main.music.play_clip("moonlight", 3.0, 0.0, true)
	main.music.act4_active = false
	main.stand.show_free()

# ---------------------------------------------------------------- input from the baton

func on_downbeat(strength := 0.6, manual := false) -> void:
	# Trigger, pinch and a real downstroke all land here, so a seated player can conduct with
	# one finger.
	if state != State.PLAY:
		return
	ictus_count += 1
	var t: float = main.music.playhead()
	var err: float = main.music.nearest_beat_error(t)
	var on := ConductLogic.is_on_beat(err)
	last_ictus_on_beat = on
	if on:
		on_beat_count += 1
		_last_on_beat_t = t
	score.add_beat(on)
	flock_warmth = minf(flock_warmth + (0.05 if on else 0.015), 1.0)
	main.flock.answer_beat(on)
	var aim: Vector3 = main.baton_water_point()
	if aim != Vector3.INF:
		main.ripples.add(aim, 0.10 if on else 0.05)
	match movement["verb"]:
		"strike":
			_try_strike(t, aim, strength, manual)
		"launch":
			main.fireworks.try_manual(aim if aim != Vector3.INF else Vector3(randf_range(-8, 8), 0, randf_range(-24, -14)))
			score.add_verb(0.035 if on else 0.012)

func on_star_lit() -> void:
	if state == State.PLAY and movement["verb"] == "stars":
		score.add_verb(1.0 / 7.0)

func on_gather_held(dt: float) -> void:
	if state == State.PLAY and movement["verb"] == "gather" and not _gather_auto:
		score.add_verb(dt / 26.0)

func _try_strike(t: float, aim: Vector3, strength: float, manual: bool) -> void:
	if t - _last_strike_t < 1.6:
		return
	var near_accent := false
	for a in _accents:
		if absf(a - t) < 0.45:
			near_accent = true
			break
	var big: bool = strength > 0.9 or manual or near_accent
	if not big:
		return
	_last_strike_t = t
	var p: Vector3 = aim if aim != Vector3.INF else Vector3(randf_range(-14, 14), 0, randf_range(-34, -18))
	main.storm.strike(p, true)
	score.add_verb(0.13 if near_accent else 0.05)

# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	_state_t += delta
	match state:
		State.ANNOUNCE:
			if _state_t >= ANNOUNCE_TIME:
				state = State.PLAY
				_state_t = 0.0
				main.music.play_clip(movement["clip"], 0.6)
				main.music.act4_active = false
		State.PLAY:
			_tick_play(delta)
		State.BOW:
			if _state_t >= BOW_TIME:
				var next := index + 1
				if _encore_used or next >= ProgramData.MOVEMENTS.size():
					_to_curtain()
				else:
					_begin(next)
		State.CURTAIN:
			if _state_t >= 40.0:
				_to_free()

func _tick_play(delta: float) -> void:
	var t: float = main.music.playhead()
	_run_cues(t)
	var tip: Vector3 = main.conductor.tip_position()
	var active: bool = tip != Vector3.ZERO
	if active:
		var speed := (tip - _prev_tip).length() / maxf(delta, 0.001)
		_prev_tip = tip
		_tip_speed = lerpf(_tip_speed, clampf(speed, 0.0, 6.0), clampf(delta * 8.0, 0.0, 1.0))
		_size.feed(tip)
		var ic: float = _ictus.feed(main.t, tip.y, delta)
		if ic > 0.0:
			on_downbeat(ic)
		if _tip_speed > 0.08:
			score.add_active(delta)
			_idle_t = 0.0
			if ConductLogic.expressive_match(_size.size(), main.music.energy):
				score.add_expressive(delta)
		else:
			_idle_t += delta
	flock_warmth = maxf(flock_warmth - delta * 0.015, 0.25)
	main.flock.warmth = flock_warmth
	_tick_verb(delta, t, tip, active)
	main.stand.tick_progress(t / maxf(main.music.duration(), 1.0), score.grade())

func _run_cues(t: float) -> void:
	var cues: Array = movement["cues"]
	while _cue_i < cues.size() and t >= float(cues[_cue_i]["at"]):
		_fire_cue(cues[_cue_i])
		_cue_i += 1

func _fire_cue(c: Dictionary) -> void:
	if c.has("mood"):
		main.mood.apply(c["mood"], float(c.get("dur", 2.0)) <= 0.0, float(c.get("dur", 2.0)))
	if c.has("weather"):
		main.weather.set_weather(c["weather"])
	if c.has("formation"):
		main.flock.set_formation(c["formation"])
	if c.has("auto_gather"):
		if not main.gather_on:
			_gather_auto = true
			main.gather_point = Vector3(0, 0, -6.5)
			main.set_gather(true)
	if c.has("finale"):
		main.music.act4_active = true
		main.megaflock.finale_swell()
		main.fireworks.start_show()
		main.fishes.ballet()
	if c.has("flyby"):
		for i in int(c["flyby"]):
			main.flock.request_flyby()
	if c.has("show"):
		main.fireworks.climax()

func _tick_verb(delta: float, t: float, tip: Vector3, active: bool) -> void:
	match movement["verb"]:
		"raise":
			_tick_raise(delta, tip, active)
		"lead":
			_tick_lead(delta, active)
		"strike":
			_tick_strike(t)
		"paint":
			_tick_paint(tip, active)
		"legato":
			_tick_legato(delta, active)
		"stars":
			_tick_stars(t)
		"gather":
			if main.gather_on and not _gather_auto:
				on_gather_held(delta)
		"launch":
			pass

func _tick_raise(delta: float, tip: Vector3, active: bool) -> void:
	_wake_t += delta
	var head_y: float = main.head_transform().origin.y
	var raised: bool = active and tip.y > head_y - HIGH_BATON
	main.mood.sun_nudge = lerpf(main.mood.sun_nudge, 1.0 if raised else 0.0, clampf(delta * 1.5, 0.0, 1.0))
	if raised:
		_wake_t += delta * 2.0
		score.add_verb(delta / 45.0)
	if _wake_t >= WAKE_INTERVAL and movement["id"] == "dawn":
		_wake_t = 0.0
		main.flock.wake_next()
		_woken += 1

func _tick_lead(delta: float, active: bool) -> void:
	var aim: Vector3 = main.baton_water_point()
	if active and aim != Vector3.INF and _tip_speed > 0.04:
		_lead_point = _lead_point.lerp(_clamp_lake(aim), clampf(delta * 1.2, 0.0, 1.0))
		score.add_verb(delta / 70.0)
		_lead_auto_t = 0.0
	else:
		_lead_auto_t += delta
		if _lead_auto_t > 2.5:
			# Nobody's steering: the line draws an easy figure eight on its own.
			var a: float = main.t * 0.16
			var auto: Vector3 = Vector3(sin(a) * 9.0, 0, -9.0 + sin(a * 2.0) * 3.5)
			_lead_point = _lead_point.lerp(auto, clampf(delta * 0.35, 0.0, 1.0))
	main.flock.lead_point = _lead_point
	main.set_reticle_lead(_lead_point)

func _clamp_lake(p: Vector3) -> Vector3:
	p.x = clampf(p.x, -14.0, 14.0)
	p.z = clampf(p.z, -22.0, -3.2)
	p.y = 0.0
	return p

func _tick_strike(t: float) -> void:
	while _accent_i < _accents.size() and t >= _accents[_accent_i] + 0.5:
		# The storm goes on regardless. An unanswered crash strikes somewhere far off.
		if t - _last_strike_t > 2.0:
			main.storm.strike(Vector3(randf_range(-24, 24), 0, randf_range(-50, -28)), false)
		_accent_i += 1

func _tick_paint(tip: Vector3, active: bool) -> void:
	var filled := 0
	if active and _tip_speed > 0.15:
		# The sweep is read by bearing from the head, so a small seated gesture still paints.
		var h: Transform3D = main.head_transform()
		var to: Vector3 = (tip - h.origin)
		var bearing := atan2(to.x, -to.z)
		var bin := clampi(int((bearing + 0.9) / 1.8 * float(_paint_bins.size())), 0, _paint_bins.size() - 1)
		if _paint_bins[bin] == 0:
			_paint_bins[bin] = 1
			score.add_verb(1.0 / float(_paint_bins.size()))
			main.audio.harp(tip, bin, -14.0)
	for b in _paint_bins:
		filled += b
	var auto: float = clampf(main.music.playhead() / maxf(main.music.duration(), 1.0) * 1.15 - 0.2, 0.0, 1.0)
	main.rainbow.set_target(maxf(float(filled) / float(_paint_bins.size()), auto))
	main.rainbow.set_bins(_paint_bins, auto)

func _tick_legato(delta: float, active: bool) -> void:
	var aim: Vector3 = main.baton_water_point()
	if active and aim != Vector3.INF and _tip_speed > 0.03 and _tip_speed < 0.9:
		_lead_point = _lead_point.lerp(_clamp_near(aim), clampf(delta * 0.8, 0.0, 1.0))
		_smooth_time += delta
		score.add_verb(delta / 60.0)
	else:
		_lead_auto_t += delta
		var a: float = main.t * 0.12
		var auto := Vector3(sin(a) * 3.0, 0, -5.2 + cos(a * 0.7) * 0.9)
		_lead_point = _lead_point.lerp(auto, clampf(delta * 0.3, 0.0, 1.0))
	main.flock.lead_point = _lead_point

func _clamp_near(p: Vector3) -> Vector3:
	p.x = clampf(p.x, -5.0, 5.0)
	p.z = clampf(p.z, -8.0, -2.8)
	p.y = 0.0
	return p

func _tick_stars(t: float) -> void:
	# Stars not lit by the end of the movement are lit by the moon, so Cygnus always completes
	# and the nest always gets its moment. Only stars you lit add to your account.
	var dur: float = main.music.duration()
	if t > dur * 0.62:
		var n: int = main.constellation.count_lit()
		var want := int(lerpf(0.0, 7.0, clampf((t - dur * 0.62) / (dur * 0.33), 0.0, 1.0)))
		if want > n:
			main.constellation.light_next()
