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
var mitten := {}         # hand -> Node3D (the posed glove and baton, for held controllers)

func setup(m) -> void:
	main = m
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
		var inst: Node3D = _make_glove(hand, anchor)
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

# ---------------------------------------------------------------- the white glove
# A conductor's white glove, a real rigged hand posed around a real baton. It replaces the old
# procedural mitten, which was a stack of balloons in the bottom of everyone's view.
const FINGER_POSES := {
	# bone suffix -> bend (radians) about the finger's own hinge
	"baton": {"Index": [0.42, 0.52, 0.32], "Middle": [0.62, 0.72, 0.42], "Ring": [0.74, 0.82, 0.50], "Little": [0.80, 0.86, 0.52]},
	"open": {"Index": [0.16, 0.22, 0.14], "Middle": [0.22, 0.28, 0.16], "Ring": [0.28, 0.32, 0.18], "Little": [0.34, 0.36, 0.20]},
}
const GRIP := Vector3(0.012, 0.030, 0.125)  # the wrist, placed so thumb and index meet at the cork
const BATON_LEN := 0.37

var baton_tip: Node3D

func _make_glove(hand: String, anchor: Node3D) -> Node3D:
	var root := Node3D.new()
	# Into the tree before posing: a skeleton out of the tree drops poses set on it.
	anchor.add_child(root)
	var scene: PackedScene = load(HAND_SCENES[hand])
	var inst: Node3D = scene.instantiate()
	inst.position = GRIP
	root.add_child(inst)
	_add_sleeve(root, GRIP)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.92, 0.89)
	mat.roughness = 0.72
	mat.rim_enabled = true
	mat.rim = 0.4
	mat.rim_tint = 0.6
	var mi := inst.find_child("*Mesh*", true, false) as MeshInstance3D
	if mi:
		mi.material_override = mat
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	if skel:
		_pose_fingers(skel, hand, FINGER_POSES["baton"] if hand == "right" else FINGER_POSES["open"], hand == "right")
	if hand == "right":
		_add_baton(root)
	return root

func _add_sleeve(root: Node3D, wrist: Vector3) -> void:
	# A white shirt cuff and a tailcoat sleeve. It closes the wrist, and it says "conductor" the
	# moment you see your own arm.
	var cuff := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.036
	cm.bottom_radius = 0.038
	cm.height = 0.04
	cm.radial_segments = 14
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	cuff.mesh = cm
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.91, 0.88)
	white.roughness = 0.6
	cuff.material_override = white
	cuff.rotation_degrees = Vector3(90, 0, 0)
	cuff.scale = Vector3(1, 1, 0.82)
	cuff.position = wrist + Vector3(0, 0, 0.012)
	root.add_child(cuff)
	var coat := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.050   # the elbow end: rotated below, the cylinder's top points back up the arm
	sm.bottom_radius = 0.040
	sm.height = 0.22
	sm.radial_segments = 14
	sm.rings = 1
	sm.cap_bottom = false
	sm.cap_top = false
	coat.mesh = sm
	# The sleeve dissolves toward the elbow: you only need the first hand's width of it to read
	# "tailcoat". A solid arm reaching toward your face filled a quarter of the view.
	var black := ShaderMaterial.new()
	black.shader = load("res://shaders/sleeve.gdshader")
	coat.material_override = black
	coat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coat.rotation_degrees = Vector3(90, 0, 0)
	coat.scale = Vector3(1, 1, 0.82)
	coat.position = wrist + Vector3(0, 0, 0.135)
	root.add_child(coat)

func _pose_fingers(skel: Skeleton3D, hand: String, pose: Dictionary, grip: bool) -> void:
	var side := "Right" if hand == "right" else "Left"
	for finger in pose:
		var bends: Array = pose[finger]
		var parts := ["Proximal", "Intermediate", "Distal"]
		for i in 3:
			var b := skel.find_bone(side + finger + parts[i])
			if b < 0:
				continue
			# Curl about the hand's own side axis, whatever axis the bone's rest happens to use.
			var inv := skel.get_bone_global_rest(b).basis.orthonormalized().inverse()
			var axis := (inv * Vector3.RIGHT).normalized()
			skel.set_bone_pose_rotation(b, skel.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(axis, -float(bends[i])))
	# Thumb opposes the index, pinching the baton's cork.
	if grip:
		for pair in [["ThumbMetacarpal", 0.42, -0.25], ["ThumbProximal", 0.30, 0.0], ["ThumbDistal", 0.42, 0.0]]:
			var b := skel.find_bone(side + str(pair[0]))
			if b < 0:
				continue
			var inv := skel.get_bone_global_rest(b).basis.orthonormalized().inverse()
			var ax := (inv * Vector3.FORWARD).normalized()
			var ay := (inv * Vector3.UP).normalized()
			skel.set_bone_pose_rotation(b, skel.get_bone_rest(b).basis.get_rotation_quaternion()
				* Quaternion(ay, float(pair[2])) * Quaternion(ax, -float(pair[1])))

func _add_baton(root: Node3D) -> void:
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0016
	cm.bottom_radius = 0.0042
	cm.height = BATON_LEN
	cm.radial_segments = 8
	cm.rings = 1
	shaft.mesh = cm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.95, 0.94, 0.90)
	wood.roughness = 0.38
	wood.emission_enabled = true
	wood.emission = Color(0.95, 0.94, 0.90)
	wood.emission_energy_multiplier = 0.25  # stays readable against a night sky
	shaft.material_override = wood
	shaft.rotation_degrees = Vector3(-90, 0, 0)
	shaft.position = Vector3(0, 0, -BATON_LEN * 0.5)
	root.add_child(shaft)
	var cork := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.012
	bm.height = 0.034
	bm.radial_segments = 10
	bm.rings = 5
	cork.mesh = bm
	var cm2 := StandardMaterial3D.new()
	cm2.albedo_color = Color(0.46, 0.31, 0.18)
	cm2.roughness = 0.8
	cork.material_override = cm2
	cork.rotation_degrees = Vector3(90, 0, 0)
	cork.position = Vector3(0, 0, 0.012)
	root.add_child(cork)
	baton_tip = Node3D.new()
	baton_tip.position = Vector3(0, 0, -BATON_LEN)
	root.add_child(baton_tip)

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

var desktop_tip := Vector3.ZERO  # mouse or autotest baton, when there's no XR session

func tip_position() -> Vector3:
	# baton tip = the arbitrated right-hand pose, so the sparkle trail, the tip
	# light and the aim ray all track the same thing in either input mode
	if not main.xr_active:
		return desktop_tip
	if main.hand_input and main.hand_input.active("right"):
		var t: Transform3D = main.hand_input.pose("right")
		# A bare finger has no baton in it: the conducting point is the fingertip. With a
		# controller, it's the actual tip of the actual baton you can see.
		if main.hand_input.bare("right") or baton_tip == null or not baton_tip.is_inside_tree():
			return t.origin + (-t.basis.z) * 0.05
		return baton_tip.global_position
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

func _desktop_hand() -> void:
	# In preview, the mitten and baton ride the mouse, so stills and clips show a conductor.
	var anchor: Node3D = anchors["right"]
	var live := desktop_tip != Vector3.ZERO
	anchor.visible = live
	if live:
		var h: Transform3D = main.head_transform()
		# Held the way a conductor holds it: out from a hand at the right of the body, not
		# along the line of sight, so a viewer can see the whole baton.
		var shoulder: Vector3 = h.origin + h.basis.x * 0.26 - h.basis.y * 0.46 + (-h.basis.z) * 0.10
		var to := (desktop_tip - shoulder).normalized()
		var basis := Basis.looking_at(to, h.basis.y)
		# Rolled a little toward thumb-up, the way a wrist rests when conducting.
		anchor.global_transform = Transform3D(basis.rotated(to, deg_to_rad(28.0)), desktop_tip - to * BATON_LEN)
		(anchor.get_child(0) as Node3D).rotation = Vector3.ZERO  # the grip tuner is for held controllers

func _show_left_desktop() -> void:
	# The other hand stays out of frame until asked for, as it usually is on a podium.
	var a: Node3D = anchors["left"]
	a.visible = false

func _process(delta: float) -> void:
	if main.hand_input == null:
		return
	if not main.xr_active:
		_desktop_hand()
		_show_left_desktop()
		var dtip := tip_position()
		if dtip != Vector3.ZERO:
			var dspeed := (dtip - _prev_tip).length() / maxf(delta, 0.001)
			_prev_tip = dtip
			_speed_avg = lerpf(_speed_avg, clampf(dspeed, 0.0, 5.0), clampf(delta * 6.0, 0, 1))
			conduct_energy = clampf(_speed_avg / 3.2, 0.0, 1.0)
			sparkles.global_position = dtip
			sparkles.emitting = _speed_avg > 0.8
			sparkle_mat.emission_energy_multiplier = 2.2 + conduct_energy * 3.5 + main.music.energy * 1.5
			tip_light.global_position = dtip
			tip_light.light_energy = clampf(conduct_energy * 1.1 + main.music.energy * 0.25, 0.0, 1.4) * 0.8
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
