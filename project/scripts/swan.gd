class_name Swan
extends Node3D
# One gliding swan: wander/attract/gather steering + neck bob, wing flap, wake ripples.

var main   # SwanLakeMain (untyped: cyclic)
var flock  # SwanFlock (untyped: cyclic)
var neck: Node3D
var wing_l: Node3D
var wing_r: Node3D
var heading := 0.0
var speed := 0.4
var wander_seed := 0.0
var wake_timer := 0.0
var flap_timer := 0.0
var flap_phase := -1.0  # <0 idle, else 0..1 through flap
var gather_slot := Vector3.INF
var bow_amount := 0.0
var neck_rest_rot: Vector3
var arrived := false

func setup(m, f, model: Node3D, seed_val: float) -> void:
	main = m
	flock = f
	wander_seed = seed_val
	add_child(model)
	neck = model.find_child("NeckHead", true, false)
	wing_l = model.find_child("WingL", true, false)
	wing_r = model.find_child("WingR", true, false)
	if neck:
		neck_rest_rot = neck.rotation
	heading = randf() * TAU
	flap_timer = randf_range(14.0, 40.0)

func steer(delta: float, t: float) -> void:
	var pos := global_position
	var desired := Vector3.ZERO
	var desired_speed := 0.42
	if gather_slot != Vector3.INF:
		var to_slot := gather_slot - pos
		to_slot.y = 0
		if to_slot.length() > 0.25:
			desired = to_slot.normalized()
			desired_speed = clampf(to_slot.length() * 0.8, 0.2, 0.9)
			arrived = false
		else:
			desired_speed = 0.0
			arrived = true
			# face the user while bowing
			var face: Vector3 = main.user_position() - pos
			face.y = 0
			heading = lerp_angle(heading, atan2(-face.x, -face.z), delta * 2.0)
	elif flock.attract_active:
		var to_p: Vector3 = flock.attract_point - pos
		to_p.y = 0
		if to_p.length() > 1.2:
			desired = to_p.normalized()
			desired_speed = 0.95
	else:
		# wander: smooth pseudo-noise heading drift + soft pull to roam anchor
		var wob := sin(t * 0.13 + wander_seed * 7.0) + 0.6 * sin(t * 0.31 + wander_seed * 3.0)
		desired = Vector3(sin(heading + wob * 0.9), 0, -cos(heading + wob * 0.9))
		var anchor: Vector3 = flock.roam_anchor
		var to_anchor := anchor - pos
		to_anchor.y = 0
		if to_anchor.length() > 7.0:
			desired = (desired + to_anchor.normalized() * 0.8).normalized()
		desired_speed = 0.35 + 0.15 * sin(t * 0.21 + wander_seed * 11.0) + flock.music_energy() * 0.25
	# separation + keep off the dock area + stay in lake bounds
	for other in flock.swans:
		if other == self:
			continue
		var away: Vector3 = pos - other.global_position
		away.y = 0
		var d := away.length()
		if d < 1.1 and d > 0.001:
			desired += away.normalized() * (1.1 - d) * 1.6
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
		heading = lerp_angle(heading, target_heading, delta * 0.9)
	speed = lerpf(speed, desired_speed, delta * 1.2)

func update_swan(delta: float, t: float) -> void:
	steer(delta, t)
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	global_position += fwd * speed * delta
	global_position.y = main.water_height(global_position.x, global_position.z) - 0.02
	rotation.y = heading
	# gentle roll into motion + bob pitch
	rotation.z = lerpf(rotation.z, sin(t * 0.9 + wander_seed) * 0.02, delta * 2.0)
	rotation.x = lerpf(rotation.x, sin(t * 0.7 + wander_seed * 2.0) * 0.02, delta * 2.0)
	# neck idle bob / bow
	var want_bow := 1.0 if (gather_slot != Vector3.INF and arrived) else 0.0
	bow_amount = lerpf(bow_amount, want_bow, delta * 2.2)
	if neck:
		var idle := sin(t * 0.8 + wander_seed * 5.0) * 0.06
		neck.rotation = neck_rest_rot + Vector3(idle - bow_amount * 0.85, 0, 0)
	# occasional wing stretch-flap (also once when a gather begins)
	flap_timer -= delta
	if flap_timer <= 0.0 and flap_phase < 0.0:
		flap_phase = 0.0
		flap_timer = randf_range(18.0, 46.0)
	if flap_phase >= 0.0:
		flap_phase += delta / 1.6
		if flap_phase >= 1.0:
			flap_phase = -1.0
			_set_wings(0.0, t)
		else:
			var lift := sin(flap_phase * PI)
			var beat := sin(flap_phase * PI * 5.0) * 0.35 * lift
			_set_wings(lift * 1.05 + beat, t)
	else:
		_set_wings(bow_amount * 0.25, t)
	# wake
	wake_timer -= delta
	if wake_timer <= 0.0 and speed > 0.15:
		wake_timer = randf_range(0.8, 1.15)
		var tail := global_position - fwd * 0.35
		main.ripples.add(tail, clampf(speed * 0.16, 0.04, 0.13))

func _set_wings(raise: float, _t: float) -> void:
	if wing_l:
		wing_l.rotation.z = raise * 0.9
	if wing_r:
		wing_r.rotation.z = -raise * 0.9

func trigger_flap() -> void:
	if flap_phase < 0.0:
		flap_phase = 0.0
