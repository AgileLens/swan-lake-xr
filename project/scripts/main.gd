class_name SwanLakeMain
extends Node3D
# Swan Lake XR — orchestrator. Builds the entire scene in code (no complex tscn to break).
# XR when OpenXR initializes (device); desktop preview rig otherwise.
# NOTE: this Mac has the godot-visionos-pilot OpenXR-OSX streaming runtime installed, so
# OpenXR "succeeds" on desktop — macOS therefore defaults to preview unless --xr is passed.

const LAKE_CENTER := Vector3(0, 0, -10)

var t := 0.0
var xr_active := false
var origin: XROrigin3D
var controllers: Array[XRController3D] = []
var reticle: MeshInstance3D
var water_mat: ShaderMaterial
var sky_mat: ShaderMaterial
var beam_mat: ShaderMaterial
var env: Environment
var moon: DirectionalLight3D
var fireflies: GPUParticles3D
var firefly_mat: StandardMaterial3D
var beam: MeshInstance3D
var flock: SwanFlock
var music: MusicDirector
var ripples: RippleField
var mood: MoodKit
var gather_on := false
var gather_point := Vector3(0, 0, -6.5)
var attract_until := 0.0
var attract_point := Vector3.ZERO
var beam_alpha := 0.0

func _ready() -> void:
	_build_environment()
	_build_water()
	_build_dock()
	_build_shore()
	_build_fireflies()
	_build_beam()
	ripples = RippleField.new()
	add_child(ripples)
	ripples.water_mat = water_mat
	flock = SwanFlock.new()
	add_child(flock)
	flock.main = self
	flock.spawn(8)
	music = MusicDirector.new()
	add_child(music)
	mood = MoodKit.new()
	add_child(mood)
	mood.setup(self)
	mood.apply("night", true)
	_init_xr_or_preview()

func _build_environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.012
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.shadow_enabled = false
	moon.light_energy = 0.35
	add_child(moon)
	_aim_moon(Vector3(-0.22, 0.28, -0.93))

func _aim_moon(dir_to_moon: Vector3) -> void:
	dir_to_moon = dir_to_moon.normalized()
	sky_mat.set_shader_parameter("moon_dir", dir_to_moon)
	if water_mat:
		water_mat.set_shader_parameter("moon_dir", dir_to_moon)
	moon.look_at_from_position(Vector3.ZERO, -dir_to_moon, Vector3.UP)

func _build_water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(240, 240)
	mesh.subdivide_width = 90
	mesh.subdivide_depth = 90
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = water_mat
	mi.position = Vector3(0, 0, -40)
	add_child(mi)

func _build_dock() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.16, 0.11, 0.08)
	wood.roughness = 0.95
	var deck := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 0.1, 4.0)
	deck.mesh = bm
	deck.material_override = wood
	deck.position = Vector3(0, 0.30, 0.6)  # walkway; user stands near front edge
	add_child(deck)
	for i in 6:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.08
		cm.height = 0.9
		post.mesh = cm
		post.material_override = wood
		var sx: float = (1.1 if i % 2 == 0 else -1.1)
		post.position = Vector3(sx, 0.12, 0.6 - 1.7 + float(i / 2) * 1.7)
		add_child(post)

func _build_shore() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.015, 0.02, 0.03)
	dark.roughness = 1.0
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# far shore hill silhouettes
	for i in 10:
		var a := TAU * float(i) / 10.0 + rng.randf_range(-0.15, 0.15)
		var r := rng.randf_range(70.0, 95.0)
		var hill := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(18, 34)
		sm.height = rng.randf_range(7, 14)
		hill.mesh = sm
		hill.material_override = dark
		hill.position = LAKE_CENTER + Vector3(cos(a) * r, -0.5, sin(a) * r)
		add_child(hill)
	# pine silhouettes on nearer ring (skip the arc behind the dock)
	for i in 26:
		var a := rng.randf_range(0.0, TAU)
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.85:
			continue  # leave open water toward the moon
		var r := rng.randf_range(46.0, 62.0)
		var pine := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = rng.randf_range(1.2, 2.2)
		cm.height = rng.randf_range(4.0, 8.0)
		pine.mesh = cm
		pine.material_override = dark
		pine.position = LAKE_CENTER + Vector3(cos(a) * r, cm.height * 0.4, sin(a) * r)
		add_child(pine)
	# reeds: two tight clusters flanking the dock
	for i in 14:
		var reed := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.005
		cm2.bottom_radius = 0.016
		cm2.height = rng.randf_range(0.4, 0.8)
		reed.mesh = cm2
		reed.material_override = dark
		var side: float = (1.0 if i % 2 == 0 else -1.0)
		reed.position = Vector3(side * rng.randf_range(1.5, 2.4), cm2.height * 0.40, rng.randf_range(-0.9, 0.7))
		reed.rotation.z = rng.randf_range(-0.10, 0.10) * side
		add_child(reed)

func _build_fireflies() -> void:
	fireflies = GPUParticles3D.new()
	fireflies.amount = 70
	fireflies.lifetime = 7.0
	fireflies.preprocess = 4.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(7, 0.9, 5)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.20
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.30
	pm.turbulence_noise_scale = 1.6
	pm.scale_min = 0.45
	pm.scale_max = 1.0
	fireflies.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	firefly_mat = StandardMaterial3D.new()
	firefly_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	firefly_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	firefly_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	firefly_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# radial soft-dot texture so particles read as glow points, not squares
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(0.5, 0.0)
	gtex.width = 32
	gtex.height = 32
	firefly_mat.albedo_texture = gtex
	firefly_mat.albedo_color = Color(0.35, 0.6, 0.75, 0.30)
	firefly_mat.emission_enabled = true
	firefly_mat.emission = Color(0.55, 0.85, 1.0)
	firefly_mat.emission_energy_multiplier = 2.0
	quad.material = firefly_mat
	fireflies.draw_pass_1 = quad
	fireflies.position = Vector3(0, 0.9, -4.5)
	add_child(fireflies)

func _build_beam() -> void:
	beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.85
	cm.bottom_radius = 0.60
	cm.height = 10.0
	cm.radial_segments = 24
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	beam_mat = ShaderMaterial.new()
	beam_mat.shader = load("res://shaders/beam.gdshader")
	beam.material_override = beam_mat
	beam.position = gather_point + Vector3(0, 5, 0)
	beam.visible = false
	add_child(beam)

# ------------------------------------------------------------------ XR / preview

func _init_xr_or_preview() -> void:
	var args := OS.get_cmdline_user_args()
	var force_preview: bool = ("--shot" in args) or ("--preview" in args) \
		or (OS.get_name() == "macOS" and not ("--xr" in args))
	var xr := XRServer.find_interface("OpenXR")
	if not force_preview and xr and xr.is_initialized():
		xr_active = true
		get_viewport().use_xr = true
		origin = XROrigin3D.new()
		origin.position = Vector3(0, 0.35, 0.6)  # dock deck height; front edge of walkway
		add_child(origin)
		var cam := XRCamera3D.new()
		origin.add_child(cam)
		for hand in ["left_hand", "right_hand"]:
			var c := XRController3D.new()
			c.tracker = hand
			c.pose = "aim"
			origin.add_child(c)
			_dress_controller(c)
			c.button_pressed.connect(_on_xr_button.bind(c, true))
			c.button_released.connect(_on_xr_button.bind(c, false))
			controllers.append(c)
	else:
		var rig := PreviewRig.new()
		rig.main = self
		add_child(rig)
	# shared reticle
	reticle = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.22
	tm.rings = 24
	tm.ring_segments = 12
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(0.5, 0.8, 1.0, 0.35)
	reticle.material_override = rm
	reticle.mesh = tm
	reticle.visible = false
	add_child(reticle)

func _dress_controller(c: XRController3D) -> void:
	var tip := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.014
	sm.height = 0.028
	tip.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.8, 0.9, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.85, 1.0)
	m.emission_energy_multiplier = 2.2
	tip.material_override = m
	tip.position = Vector3(0, 0, -0.05)
	c.add_child(tip)
	var rod := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.004
	cm.bottom_radius = 0.007
	cm.height = 0.26
	rod.mesh = cm
	rod.material_override = m
	rod.rotation_degrees = Vector3(-90, 0, 0)
	rod.position = Vector3(0, 0, 0.08)
	c.add_child(rod)

func _on_xr_button(button: String, c: XRController3D, pressed: bool) -> void:
	if pressed:
		match button:
			"trigger_click":
				var hit := _aim_hit(c)
				if hit != Vector3.INF:
					do_ripple(hit, 0.85)
			"grip_click":
				set_gather(true)
			"ax_button":
				mood.cycle()
			"by_button":
				music.play_finale()
	else:
		if button == "grip_click":
			set_gather(false)

func _aim_hit(c: XRController3D) -> Vector3:
	var from := c.global_position
	var dir := -c.global_transform.basis.z
	if dir.y > -0.02:
		return Vector3.INF
	var dist := from.y / -dir.y
	if dist > 60.0:
		return Vector3.INF
	return from + dir * dist

# ------------------------------------------------------------------ public verbs

func do_ripple(pos: Vector3, strength: float) -> void:
	ripples.add(pos, strength)
	if strength > 0.4:
		attract_point = pos
		attract_until = t + 6.0
		gather_point = pos

func set_gather(on: bool) -> void:
	gather_on = on
	beam.visible = true
	beam.position = Vector3(gather_point.x, 5.0, gather_point.z)
	flock.set_gather(on, gather_point)
	if on:
		do_ripple(gather_point, 0.5)

func water_height(x: float, z: float) -> float:
	return sin(x * 0.5 + t * 0.7) * 0.02 + cos(z * 0.4 + t * 0.55) * 0.02

func user_position() -> Vector3:
	if xr_active and origin:
		return origin.global_position
	return Vector3(0, 1.6, 0.6)

func _process(delta: float) -> void:
	t += delta
	water_mat.set_shader_parameter("u_time", t)
	sky_mat.set_shader_parameter("u_time", t)
	ripples.tick(t)
	var e: float = music.energy
	water_mat.set_shader_parameter("music_energy", e)
	firefly_mat.emission_energy_multiplier = 1.4 + e * 3.2
	fireflies.speed_scale = 0.8 + e * 0.9
	# beam fade
	var target_a := 0.16 if gather_on else 0.0
	beam_alpha = lerpf(beam_alpha, target_a, delta * 3.0)
	beam_mat.set_shader_parameter("alpha", beam_alpha * (1.0 + e * 0.7))
	if beam_alpha < 0.005 and not gather_on:
		beam.visible = false
	# reticle follows best controller aim
	if xr_active:
		var best := Vector3.INF
		for c in controllers:
			var h := _aim_hit(c)
			if h != Vector3.INF:
				best = h
				break
		if best != Vector3.INF:
			reticle.visible = true
			reticle.position = Vector3(best.x, water_height(best.x, best.z) + 0.03, best.z)
			var pulse := 0.30 + 0.12 * sin(t * 4.0)
			(reticle.material_override as StandardMaterial3D).albedo_color.a = pulse
		else:
			reticle.visible = false
	flock.attract_active = t < attract_until
	flock.attract_point = attract_point

func set_reticle_preview(pos: Vector3, show: bool) -> void:
	reticle.visible = show
	if show:
		reticle.position = Vector3(pos.x, water_height(pos.x, pos.z) + 0.03, pos.z)
