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
	flap_timer = randf_range(14.0, 40.0)
	preen_timer = randf_range(40.0, 90.0)

func _attach_model(model: Node3D) -> void:
	model_node = model
	add_child(model)
	neck = model.find_child("NeckHead", true, false)
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
		_set_wings(bow_amount * 0.25)
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
