class_name Swan
extends Node3D
# One swan: wander/attract/gather steering, neck bob + bow, wing flaps, wake ripples,
# occasional preen, and a full takeoff -> circle -> splash-landing flyby.

var main   # SwanLakeMain (untyped: cyclic)
var flock  # SwanFlock (untyped: cyclic)
var neck: Node3D
var wing_l: Node3D
var wing_r: Node3D
var tail: Node3D
var heading := 0.0
var speed := 0.4
var wander_seed := 0.0
var wake_timer := 0.0
var flap_timer := 0.0
var flap_phase := -1.0
var gather_slot := Vector3.INF
var bow_amount := 0.0
var neck_rest_rot: Vector3
var beak: Node3D
var beak_rest_rot: Vector3
# Dance layer. These swans are the corps' principals — they should read as
# dancers, not waterfowl on autopilot, so neck/wing/beak all take a musical
# phrase rather than a fixed idle wobble. Each swan gets its own offset in the
# phrase so the group looks choreographed instead of synchronized.
var dance_seed := 0.0
var _wing_extra := 0.0
var _beak_open := 0.0
# Head-tracking toward the conductor's baton. Eased rather than snapped, so a
# swan turns to look instead of twitching — and only when the baton is actually
# near it and roughly in front, so the whole flock doesn't stare in unison.
var _watch_gain := 0.0
var _watch_target := 0.0
const WATCH_RANGE := 9.0
const WATCH_MAX_YAW := 1.15  # rad; past this a real bird turns its body, not its neck
var arrived := false
var is_cygnet := false
var follow_target: Node3D = null
# preen
var preen_timer := 60.0
var preen_t := -1.0
# flyby
var flying := false
var fly_t := 0.0
var fly_center := Vector3.ZERO
var fly_ang0 := 0.0
var fly_r := 11.0

var model_node: Node3D

func setup(m, f, model: Node3D, seed_val: float) -> void:
	main = m
	flock = f
	wander_seed = seed_val
	_attach_model(model)
	heading = randf() * TAU
	dance_seed = seed_val
	flap_timer = randf_range(14.0, 40.0)
	preen_timer = randf_range(40.0, 90.0)

func _attach_model(model: Node3D) -> void:
	model_node = model
	add_child(model)
	neck = model.find_child("NeckHead", true, false)
	beak = model.find_child("BeakLower", true, false)
	if beak:
		beak_rest_rot = beak.rotation
	wing_l = model.find_child("WingL", true, false)
	wing_r = model.find_child("WingR", true, false)
	tail = model.find_child("TailFan", true, false)
	if neck:
		neck_rest_rot = neck.rotation

func swap_model(model: Node3D) -> void:
	if model_node:
		model_node.queue_free()
	preen_t = -1.0
	flap_phase = -1.0
	bow_amount = 0.0
	_attach_model(model)

func start_flyby() -> void:
	if flying or gather_slot != Vector3.INF or is_cygnet:
		return
	flying = true
	fly_t = 0.0
	fly_center = main.LAKE_CENTER
	var rel := global_position - fly_center
	rel.y = 0
	fly_ang0 = atan2(rel.x, rel.z)
	fly_r = clampf(rel.length() + 2.0, 9.0, 14.0)

func steer(delta: float, t: float) -> void:
	var pos := global_position
	var desired := Vector3.ZERO
	var desired_speed := 0.42
	var speed_lerp := 1.2
	if follow_target:
		var behind: Vector3 = follow_target.global_position \
			- Vector3(-sin(follow_target.rotation.y), 0, -cos(follow_target.rotation.y)) * 0.9
		var to_b := behind - pos
		to_b.y = 0
		if to_b.length() > 0.35:
			desired = to_b.normalized()
			desired_speed = clampf(to_b.length() * 1.1, 0.3, 1.3)
	elif gather_slot != Vector3.INF:
		speed_lerp = 3.0
		var to_slot := gather_slot - pos
		to_slot.y = 0
		if to_slot.length() > 0.5:
			desired = to_slot.normalized()
			desired_speed = clampf(to_slot.length() * 1.4, 0.4, 1.7)
			arrived = false
		else:
			desired_speed = 0.0
			arrived = true
			var face: Vector3 = main.user_position() - pos
			face.y = 0
			heading = lerp_angle(heading, atan2(-face.x, -face.z), delta * 3.0)
	elif flock.attract_active:
		var to_p: Vector3 = flock.attract_point - pos
		to_p.y = 0
		if to_p.length() > 1.2:
			desired = to_p.normalized()
			desired_speed = 0.95
	else:
		var wob := sin(t * 0.13 + wander_seed * 7.0) + 0.6 * sin(t * 0.31 + wander_seed * 3.0)
		desired = Vector3(sin(heading + wob * 0.9), 0, -cos(heading + wob * 0.9))
		var anchor: Vector3 = flock.roam_anchor
		var to_anchor := anchor - pos
		to_anchor.y = 0
		if to_anchor.length() > 7.0:
			desired = (desired + to_anchor.normalized() * 0.8).normalized()
		desired_speed = 0.35 + 0.15 * sin(t * 0.21 + wander_seed * 11.0) + flock.music_energy() * 0.25
	for other in flock.swans:
		if other == self:
			continue
		var away: Vector3 = pos - other.global_position
		away.y = 0
		var d := away.length()
		var min_d := 0.6 if is_cygnet else 1.1
		if d < min_d and d > 0.001:
			desired += away.normalized() * (min_d - d) * 1.6
	var from_user: Vector3 = pos - main.user_position()
	from_user.y = 0
	if from_user.length() < 2.2:
		desired += from_user.normalized() * 1.2
	var from_center: Vector3 = pos - main.LAKE_CENTER
	from_center.y = 0
	if from_center.length() > 15.0:
		desired += -from_center.normalized() * 1.5
	if desired.length() > 0.01:
		var target_heading := atan2(-desired.x, -desired.z)
		var turn := 2.4 if gather_slot != Vector3.INF else 0.9
		heading = lerp_angle(heading, target_heading, delta * turn)
	speed = lerpf(speed, desired_speed, delta * speed_lerp)

func update_swan(delta: float, t: float) -> void:
	if flying:
		_update_fly(delta, t)
		return
	steer(delta, t)
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	global_position += fwd * speed * delta
	global_position.y = main.water_height(global_position.x, global_position.z) - 0.02
	rotation.y = heading
	rotation.z = lerpf(rotation.z, sin(t * 0.9 + wander_seed) * 0.02, delta * 2.0)
	rotation.x = lerpf(rotation.x, sin(t * 0.7 + wander_seed * 2.0) * 0.02, delta * 2.0)
	var want_bow := 1.0 if (gather_slot != Vector3.INF and arrived) else 0.0
	bow_amount = lerpf(bow_amount, want_bow, delta * 4.0)
	# preen (idle only)
	preen_timer -= delta
	if preen_timer <= 0.0 and preen_t < 0.0 and gather_slot == Vector3.INF and not flock.attract_active:
		preen_t = 0.0
		preen_timer = randf_range(45.0, 95.0)
	_watch_gain = lerpf(_watch_gain, _watch_target, clampf(delta * 3.5, 0.0, 1.0))
	if neck:
		if preen_t >= 0.0:
			preen_t += delta / 4.0
			if preen_t >= 1.0:
				preen_t = -1.0
				neck.rotation = neck_rest_rot
			else:
				var k := sin(preen_t * PI)
				neck.rotation = neck_rest_rot + Vector3(0.55 * k, 0, 0)
				neck.rotation.y = 1.75 * k * (1.0 if int(wander_seed * 10.0) % 2 == 0 else -1.0)
		else:
			var idle := sin(t * 0.8 + wander_seed * 5.0) * 0.06
			neck.rotation = neck_rest_rot + Vector3(idle - bow_amount * 0.85, 0, 0)
			_dance_neck(t)
			_watch_baton()
	_update_watch_target()
	flap_timer -= delta
	if flap_timer <= 0.0 and flap_phase < 0.0:
		flap_phase = 0.0
		flap_timer = randf_range(18.0, 46.0)
	if flap_phase >= 0.0:
		flap_phase += delta / 1.6
		if flap_phase >= 1.0:
			flap_phase = -1.0
			_set_wings(0.0)
		else:
			var lift := sin(flap_phase * PI)
			var beat := sin(flap_phase * PI * 5.0) * 0.35 * lift
			_set_wings(lift * 1.05 + beat)
	else:
		_set_wings(bow_amount * 0.25 + _wing_extra)
	_dance_wings_and_beak(delta, t)
	if tail:
		tail.rotation.x = 0.35 + sin(t * 1.1 + wander_seed * 3.0) * 0.06 + bow_amount * 0.3
	wake_timer -= delta
	if wake_timer <= 0.0 and speed > 0.15:
		wake_timer = randf_range(0.8, 1.15)
		var tail_p := global_position - fwd * 0.35
		main.ripples.add(tail_p, clampf(speed * 0.16, 0.04, 0.13))

func _update_fly(delta: float, t: float) -> void:
	fly_t += delta
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	_set_wings(sin(t * 9.0) * 0.85 + 0.25)
	if fly_t < 2.2:
		# takeoff run on the water
		speed = lerpf(speed, 3.4, delta * 1.4)
		global_position += fwd * speed * delta
		global_position.y = main.water_height(global_position.x, global_position.z) + fly_t * 0.10
		if int(fly_t * 8.0) % 2 == 0:
			main.ripples.add(global_position, 0.06)
	elif fly_t < 11.0:
		var u := (fly_t - 2.2) / 8.8
		var ang := fly_ang0 + u * TAU * 1.15
		var h := sin(clampf(u * 1.25, 0, 1) * PI) * 5.0 + 0.4
		var p := fly_center + Vector3(sin(ang) * fly_r, h, cos(ang) * fly_r)
		var vel := (p - global_position) / maxf(delta, 0.001)
		global_position = p
		if vel.length() > 0.1:
			heading = atan2(-vel.x, -vel.z)
			rotation.y = heading
			rotation.z = clampf(-vel.x * 0.02, -0.5, 0.5)
	else:
		# splash landing
		flying = false
		speed = 0.6
		rotation.z = 0
		global_position.y = 0
		main.ripples.burst(global_position, 0.5)
		main.audio.play3d("splash", global_position, -4.0)

func _set_wings(raise: float) -> void:
	if wing_l:
		wing_l.rotation.z = raise * 0.9
	if wing_r:
		wing_r.rotation.z = -raise * 0.9

func trigger_flap() -> void:
	if flap_phase < 0.0:
		flap_phase = 0.0

# ---------------------------------------------------------------- baton watching

func _baton_point() -> Vector3:
	# the same tip the sparkle trail and aim ray use, so a swan looks exactly where
	# the player sees their baton — not at an approximation of it
	if main.conductor == null:
		return Vector3.INF
	var tip: Vector3 = main.conductor.tip_position()
	return Vector3.INF if tip == Vector3.ZERO else tip

func _update_watch_target() -> void:
	_watch_target = 0.0
	var tip: Vector3 = _baton_point()
	if tip == Vector3.INF:
		return
	var to_tip: Vector3 = tip - global_position
	var dist := to_tip.length()
	if dist > WATCH_RANGE:
		return
	to_tip.y = 0.0
	if to_tip.length() < 0.05:
		return
	# only if the baton is within the swan's forward arc — a swan facing away
	# shouldn't crane its neck backwards
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	var yaw := fwd.signed_angle_to(to_tip.normalized(), Vector3.UP)
	if absf(yaw) > WATCH_MAX_YAW:
		return
	# closer + more energetic conducting = more attention
	var near := 1.0 - clampf(dist / WATCH_RANGE, 0.0, 1.0)
	var energy: float = clampf(main.conductor.conduct_energy, 0.0, 1.0)
	_watch_target = clampf(near * (0.35 + energy * 0.65), 0.0, 1.0)

func _watch_baton() -> void:
	if _watch_gain < 0.01:
		return
	var tip: Vector3 = _baton_point()
	if tip == Vector3.INF:
		return
	var to_tip: Vector3 = tip - global_position
	var flat := Vector3(to_tip.x, 0.0, to_tip.z)
	if flat.length() < 0.05:
		return
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	var yaw := fwd.signed_angle_to(flat.normalized(), Vector3.UP)
	# a raised baton lifts the head too, which is what sells "it's watching you"
	var pitch := atan2(to_tip.y - 0.35, flat.length())
	neck.rotation.y += clampf(yaw, -WATCH_MAX_YAW, WATCH_MAX_YAW) * _watch_gain
	neck.rotation.x -= clampf(pitch, -0.5, 0.7) * _watch_gain * 0.6
	# final guard: the dance layer already moved this, and the sum must stay in
	# a range a neck can actually reach
	neck.rotation.x = clampf(neck.rotation.x, neck_rest_rot.x - 0.6, neck_rest_rot.x + 0.85)
	neck.rotation.y = clampf(neck.rotation.y, -1.3, 1.3)

# ---------------------------------------------------------------- the dance

func _phrase() -> float:
	# position within a 4-bar phrase, offset per swan so the corps looks
	# choreographed rather than synchronized
	return fposmod(main.music.bar_phase() + dance_seed, 1.0)

func _dance_neck(t: float) -> void:
	# The neck is a swan's whole expression — it should carry the melody. Three
	# layers: a slow port-de-bras sweep across the phrase, a faster sinuous curl,
	# and a lift that rides the music's dynamics.
	var e: float = main.music.energy
	var ph := _phrase()
	var sweep := sin(ph * TAU) * (0.16 + e * 0.20)          # side to side, phrase-long
	var curl := sin(t * 1.7 + dance_seed * TAU) * 0.09      # sinuous S in the neck
	var lift := (0.10 + e * 0.30) * (0.5 + 0.5 * sin(ph * TAU * 2.0))
	neck.rotation.y += sweep
	neck.rotation.x += curl - lift * 0.45
	# No roll on the neck: rolling while swept put the head upside down. A swan
	# tips its head by turning, not by rotating its neck about its own axis.
	# Clamped because _watch_baton() adds on top of this and the two together
	# were arching the neck right over backwards.
	neck.rotation.x = clampf(neck.rotation.x, neck_rest_rot.x - 0.55, neck_rest_rot.x + 0.75)
	neck.rotation.y = clampf(neck.rotation.y, -1.25, 1.25)

func _dance_wings_and_beak(delta: float, t: float) -> void:
	var e: float = main.music.energy
	var ph := _phrase()
	# Wings: held half-open through the phrase like a dancer's arms, opening
	# further as the music swells, with one wing leading the other (a real corps
	# never lifts both arms perfectly together).
	var open := (0.10 + e * 0.85) * (0.45 + 0.55 * sin(ph * TAU))
	_wing_extra = lerpf(_wing_extra, maxf(open, 0.0), clampf(delta * 3.0, 0.0, 1.0))
	if wing_l and wing_r:
		var lead := sin(ph * TAU + 0.6) * 0.18 * (0.3 + e)
		wing_l.rotation.z += lead
		wing_r.rotation.z += lead      # same sign = asymmetry, which reads as a gesture
		# a little forward reach at the top of the phrase
		var reach := maxf(sin(ph * TAU), 0.0) * (0.10 + e * 0.25)
		wing_l.rotation.x = -reach
		wing_r.rotation.x = -reach
	# Beak: opens on the musical accents — the swans are singing along. Snaps
	# open, closes slowly, so it reads as articulation rather than chatter.
	if beak:
		var accent: float = 1.0 if (main.music.swell_flag or (e > 0.45 and _beat_edge())) else 0.0
		if accent > 0.0:
			_beak_open = 1.0
		_beak_open = maxf(_beak_open - delta * 2.4, 0.0)
		beak.rotation = beak_rest_rot + Vector3(_beak_open * 0.55, 0, 0)

var _last_beat := 0.0

func _beat_edge() -> bool:
	var b: float = main.music.beat_phase()
	var crossed := b < _last_beat   # wrapped past the beat
	_last_beat = b
	return crossed
