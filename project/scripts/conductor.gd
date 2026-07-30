class_name Conductor
extends Node
# White conductor hands + baton on the controllers, Fantasia sparkle trail at the tip,
# smoothed conducting energy. Bonus: if OpenXR hand tracking is live, pinch modulates energy.

var main  # SwanLakeMain
var right_hand_node: Node3D
var left_hand_node: Node3D
var sparkles: GPUParticles3D
var sparkle_mat: StandardMaterial3D
var tip_light: OmniLight3D
var conduct_energy := 0.0
var _prev_tip := Vector3.ZERO
var _speed_avg := 0.0
var pinch := 0.0
var sparkle_level := 1  # 0 low 1 med 2 high (menu)

# Grip pose: how the hand+baton sits on the controller, relative to the aim pose.
# The right feel is a headset-only judgment call, so ship presets on an orb plus a
# live fine-tune (right stick, menu open) instead of one hardcoded guess.
const POSE_PRESETS := [
	{"name": "aim", "pitch": 0.0},
	{"name": "lifted", "pitch": -20.0},
	{"name": "relaxed", "pitch": -35.0},
	{"name": "natural", "pitch": -50.0},
	{"name": "downbeat", "pitch": -65.0},
]
const POSE_CFG := "user://baton_pose.cfg"
var pose_index := 2  # "relaxed" -35 = v2 shipped guess
var pose_fine := 0.0  # stick-dialed degrees on top of the preset
var hand_instances: Array[Node3D] = []
var _fine_dirty := false

func setup(m) -> void:
	main = m
	var hands: PackedScene = load("res://assets/hands.glb")
	for c in main.controllers:
		var inst: Node3D = hands.instantiate()
		var hl: Node3D = inst.find_child("HandL", true, false)
		var hr: Node3D = inst.find_child("HandR", true, false)
		if c.tracker == "left_hand":
			if hr: hr.visible = false
			left_hand_node = inst
		else:
			if hl: hl.visible = false
			right_hand_node = inst
			if hr: hr.position = Vector3.ZERO
		inst.position = Vector3(0, -0.01, 0.02)
		c.add_child(inst)
		hand_instances.append(inst)
	_load_pose()
	_apply_pose()
	# sparkle trail (world-space so it trails behind motion)
	sparkles = GPUParticles3D.new()
	sparkles.amount = 130
	sparkles.lifetime = 0.85
	sparkles.local_coords = false
	sparkles.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, -0.25, 0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.4
	pm.spread = 180.0
	pm.damping_min = 1.2
	pm.damping_max = 2.4
	pm.scale_min = 0.35
	pm.scale_max = 1.0
	var sc := CurveTexture.new(); var cv := Curve.new()
	cv.add_point(Vector2(0, 1)); cv.add_point(Vector2(1, 0))
	sc.curve = cv
	pm.scale_curve = sc
	sparkles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.016, 0.016)
	sparkle_mat = StandardMaterial3D.new()
	sparkle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sparkle_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sparkle_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5); grad.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	grad.gradient = g
	sparkle_mat.albedo_texture = grad
	sparkle_mat.albedo_color = Color(1, 1, 1, 0.7)
	sparkle_mat.emission_enabled = true
	sparkle_mat.emission = Color(0.75, 0.9, 1.0)
	sparkle_mat.emission_energy_multiplier = 3.0
	quad.material = sparkle_mat
	sparkles.draw_pass_1 = quad
	main.add_child(sparkles)
	tip_light = OmniLight3D.new()
	tip_light.omni_range = 2.4
	tip_light.light_energy = 0.0
	tip_light.shadow_enabled = false
	main.add_child(tip_light)

func tip_position() -> Vector3:
	var c := _right()
	if c:
		return c.global_position + (-c.global_transform.basis.z) * 0.30
	return Vector3.ZERO

func _right() -> XRController3D:
	for c in main.controllers:
		if c.tracker == "right_hand":
			return c
	return null

func set_sparkle_level(lv: int) -> void:
	sparkle_level = lv
	sparkles.amount = [50, 130, 240][clampi(lv, 0, 2)]

# ---------------------------------------------------------------- baton pose

func effective_pitch() -> float:
	var base: float = POSE_PRESETS[pose_index].pitch
	return clampf(base + pose_fine, -90.0, 15.0)

func pose_label() -> String:
	return "%s %d°" % [POSE_PRESETS[pose_index].name, roundi(effective_pitch())]

func cycle_pose() -> void:
	pose_index = (pose_index + 1) % POSE_PRESETS.size()
	pose_fine = 0.0
	_apply_pose()
	_save_pose()

func _apply_pose() -> void:
	for inst in hand_instances:
		inst.rotation_degrees = Vector3(effective_pitch(), 0, 0)

func _load_pose() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(POSE_CFG) == OK:
		pose_index = clampi(cfg.get_value("baton", "preset", pose_index), 0, POSE_PRESETS.size() - 1)
		pose_fine = clampf(cfg.get_value("baton", "fine", 0.0), -45.0, 45.0)

func _save_pose() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("baton", "preset", pose_index)
	cfg.set_value("baton", "fine", pose_fine)
	cfg.save(POSE_CFG)
	# lands in logcat: the number to hardcode once Alex settles on a feel
	print("[baton] pose=", pose_label(), " (preset=", POSE_PRESETS[pose_index].name,
		" fine=", snappedf(pose_fine, 0.1), ")")

func _tune_pose(delta: float) -> void:
	# right stick Y while the orb menu is open: dial pitch live, save on release
	var c := _right()
	if c == null:
		return
	var stick: Vector2 = c.get_vector2("primary")
	if absf(stick.y) > 0.3:
		pose_fine = clampf(pose_fine + stick.y * 30.0 * delta, -45.0, 45.0)
		_apply_pose()
		_fine_dirty = true
	elif _fine_dirty:
		_fine_dirty = false
		_save_pose()

func _process(delta: float) -> void:
	if main.controllers.is_empty():
		return
	if main.menu and main.menu.open:
		_tune_pose(delta)
	var tip := tip_position()
	var speed := (tip - _prev_tip).length() / maxf(delta, 0.001)
	_prev_tip = tip
	_speed_avg = lerpf(_speed_avg, clampf(speed, 0.0, 5.0), clampf(delta * 6.0, 0, 1))
	_update_pinch()
	conduct_energy = clampf(_speed_avg / 3.2 + pinch * 0.45, 0.0, 1.0)
	sparkles.global_position = tip
	sparkles.emitting = _speed_avg > 1.05 or pinch > 0.5
	sparkle_mat.emission_energy_multiplier = 2.2 + conduct_energy * 3.5 + main.music.energy * 1.5
	tip_light.global_position = tip
	tip_light.light_energy = clampf(conduct_energy * 1.1 + main.music.energy * 0.25, 0.0, 1.4) * 0.8

func set_accent(c: Color) -> void:
	sparkle_mat.emission = c
	tip_light.light_color = c.lerp(Color.WHITE, 0.4)

func _update_pinch() -> void:
	# best-effort OpenXR hand tracking: pinch strength from thumb-index distance
	pinch = 0.0
	var tracker: XRHandTracker = XRServer.get_tracker("/user/hand_tracker/right") as XRHandTracker
	if tracker and tracker.has_tracking_data:
		var thumb := tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_THUMB_TIP)
		var index := tracker.get_hand_joint_transform(XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP)
		var d := (thumb.origin - index.origin).length()
		pinch = clampf(remap(d, 0.075, 0.02, 0.0, 1.0), 0.0, 1.0)
