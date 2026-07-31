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
var anchors := {}  # hand -> Node3D, positioned from HandInput each frame
var _fine_dirty := false
# Real skinned hand mesh (XRHandModifier3D + the MIT-licensed rigged hand from
# godot-demo-projects — see CREDITS.md), toggled against the procedural mitten:
# mitten visible while holding a controller (it IS the baton grip), skinned hand
# visible + posed by real joint data when bare. Two visuals, one arbitration
# source (HandInput.bare()) — no third mechanism to disagree with the other two.
var skin_mesh := {}      # hand -> Node3D (the Humanoid scene instance)
var skin_modifier := {}  # hand -> XRHandModifier3D
var mitten := {}         # hand -> Node3D (the procedural hands.glb instance)

func setup(m) -> void:
	main = m
	var hands: PackedScene = load("res://assets/hands.glb")
	# Anchored in world space and driven from HandInput each frame rather than
	# parented to the controller, so the same rig serves controllers and bare
	# hands. Each anchor hides itself when its hand isn't tracked — the same
	# "each side independently hides itself" resolution Tank Commander landed on,
	# which avoids a third arbitration mechanism that can disagree with the other two.
	for hand in main.HANDS:
		var anchor := Node3D.new()
		anchor.name = "HandAnchor_%s" % hand
		anchor.visible = false
		main.add_child(anchor)
		var inst: Node3D = hands.instantiate()
		var hl: Node3D = inst.find_child("HandL", true, false)
		var hr: Node3D = inst.find_child("HandR", true, false)
		if hand == "left":
			if hr: hr.visible = false
		else:
			if hl: hl.visible = false
			if hr: hr.position = Vector3.ZERO
		inst.position = Vector3(0, -0.01, 0.02)
		anchor.add_child(inst)
		anchors[hand] = anchor
		hand_instances.append(inst)
		mitten[hand] = inst
		_setup_skin_mesh(hand, anchor)
	left_hand_node = anchors["left"]
	right_hand_node = anchors["right"]
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

const HAND_SCENES := {
	"left": "res://assets/hand_mesh/LeftHandHumanoid.gltf",
	"right": "res://assets/hand_mesh/RightHandHumanoid.gltf",
}

func _setup_skin_mesh(hand: String, _anchor: Node3D) -> void:
	# Real hand tracking only exists in an actual XR session with a live tracking
	# origin — desktop preview has no XRHandTracker data, so there's nothing for
	# XRHandModifier3D to read and the mitten already covers that case.
	if not main.xr_active or main.origin == null:
		return
	var scene: PackedScene = load(HAND_SCENES[hand])
	var inst: Node3D = scene.instantiate()
	# CRITICAL: parented to XROrigin3D directly, at identity — NOT to the
	# per-frame anchor. XRHandModifier3D reads joint transforms that are already
	# relative to the tracking origin (confirmed against hand_input.gd's own
	# main.origin.global_transform * joint_transform math); if this sat under the
	# anchor, which _track_hands() overwrites every frame with a fingertip-aim
	# pose for the baton, the skeleton's own joint-driven positioning would be
	# double-transformed and the hand would render in the wrong place.
	main.origin.add_child(inst)
	inst.visible = false
	# The demo asset's hand.png is a generic anatomical skin tone — tint it toward
	# the mitten's ivory/pearl look so the two hand visuals read as one character
	# rather than a swap between two different art styles.
	var mesh_inst: MeshInstance3D = inst.find_child("*Mesh*", true, false) as MeshInstance3D
	if mesh_inst:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.92, 0.93, 0.95)
		mat.roughness = 0.55
		mesh_inst.material_override = mat
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	if skel:
		var mod := XRHandModifier3D.new()
		mod.hand_tracker = "/user/hand_tracker/%s" % hand
		skel.add_child(mod)
		skin_modifier[hand] = mod
	else:
		push_warning("[conductor] no Skeleton3D found in " + HAND_SCENES[hand])
	skin_mesh[hand] = inst

func tip_position() -> Vector3:
	# baton tip = the arbitrated right-hand pose, so the sparkle trail, the tip
	# light and the aim ray all track the same thing in either input mode
	if main.hand_input and main.hand_input.active("right"):
		var t: Transform3D = main.hand_input.pose("right")
		# a bare finger has no baton in it — shorten the reach to the fingertip
		var reach: float = 0.30 if not main.hand_input.bare("right") else 0.05
		return t.origin + (-t.basis.z) * reach
	return Vector3.ZERO

func set_sparkle_level(lv: int) -> void:
	sparkle_level = lv
	sparkles.amount = [50, 130, 240][clampi(lv, 0, 2)]

# ---------------------------------------------------------------- baton pose

func effective_pitch() -> float:
	# Alex + Dax, in-headset on "downbeat -65°": "positions the hand flipped and
	# mirrored — thumb in the right place but upside down, fingers where the
	# wrist should be." A single-axis (X) rotation never moves a point's X
	# coordinate — which is exactly why the thumb (offset only in X) stayed put
	# while everything offset in Y/Z (fingers, wrist) appeared to swap: this is
	# what a pure pitch approaching ±90° looks like on a model with no strong
	# "this side is up" cues at rest, not a mirroring bug. The old [-90, 15]
	# clamp let "downbeat" (-65) plus the full fine-tune range (±45) reach
	# exactly -90 — the worst point, where the model reads edge-on and folds
	# in projection. Tightened so the combination can no longer reach it.
	var base: float = POSE_PRESETS[pose_index].pitch
	return clampf(base + pose_fine, -78.0, 15.0)

func pose_label() -> String:
	return "%s %d°" % [POSE_PRESETS[pose_index].name, roundi(effective_pitch())]

func cycle_pose() -> void:
	pose_index = (pose_index + 1) % POSE_PRESETS.size()
	pose_fine = 0.0
	_apply_pose()
	_save_pose()

func _apply_pose() -> void:
	# The grip offset describes how a hand sits on a *controller*; a tracked bare
	# hand already is the real pose, so it gets no offset.
	for hand in main.HANDS:
		var anchor: Node3D = anchors.get(hand)
		if anchor == null or anchor.get_child_count() == 0:
			continue
		var bare: bool = main.hand_input != null and main.hand_input.bare(hand)
		var inst: Node3D = anchor.get_child(0)
		inst.rotation_degrees = Vector3(0.0 if bare else effective_pitch(), 0, 0)

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
	# (controller-only — there is no stick to push in bare-hand mode)
	var c: XRController3D = main.hand_input.controller("right")
	if c == null or main.hand_input.bare("right"):
		return
	var stick: Vector2 = c.get_vector2("primary")
	if absf(stick.y) > 0.3:
		pose_fine = clampf(pose_fine + stick.y * 30.0 * delta, -45.0, 45.0)
		_apply_pose()
		_fine_dirty = true
	elif _fine_dirty:
		_fine_dirty = false
		_save_pose()

func _track_hands() -> void:
	for hand in main.HANDS:
		var anchor: Node3D = anchors[hand]
		var live: bool = main.hand_input.active(hand)
		var bare: bool = main.hand_input.bare(hand)
		# Real skinned hand for bare tracking, the mitten+baton for a held
		# controller — the mitten IS the baton grip, so it stays for controllers.
		var skin: Node3D = skin_mesh.get(hand)
		if skin:
			skin.visible = live and bare
		var m: Node3D = mitten.get(hand)
		if m:
			m.visible = live and not bare
		anchor.visible = live
		if live:
			anchor.global_transform = main.hand_input.pose(hand)

func _process(delta: float) -> void:
	if not main.xr_active or main.hand_input == null:
		return
	_track_hands()
	_apply_pose()  # source can flip mid-session; the offset must follow it
	if not main.hand_input.active("right"):
		sparkles.emitting = false
		tip_light.light_energy = 0.0
		return
	if main.menu and main.menu.open:
		_tune_pose(delta)
	var tip := tip_position()
	var speed := (tip - _prev_tip).length() / maxf(delta, 0.001)
	_prev_tip = tip
	_speed_avg = lerpf(_speed_avg, clampf(speed, 0.0, 5.0), clampf(delta * 6.0, 0, 1))
	pinch = main.hand_input.pinch["right"]
	conduct_energy = clampf(_speed_avg / 3.2 + pinch * 0.45, 0.0, 1.0)
	sparkles.global_position = tip
	sparkles.emitting = _speed_avg > 1.05 or pinch > 0.5
	sparkle_mat.emission_energy_multiplier = 2.2 + conduct_energy * 3.5 + main.music.energy * 1.5
	tip_light.global_position = tip
	tip_light.light_energy = clampf(conduct_energy * 1.1 + main.music.energy * 0.25, 0.0, 1.4) * 0.8

func set_accent(c: Color) -> void:
	sparkle_mat.emission = c
	tip_light.light_color = c.lerp(Color.WHITE, 0.4)

# pinch now comes from HandInput (single owner, with hysteresis) rather than a
# second thumb-index measurement that could drift out of agreement with it
