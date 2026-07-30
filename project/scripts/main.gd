class_name SwanLakeMain
extends Node3D
# Swan Lake XR v2 — orchestrator. Scene + systems built in code.
# macOS defaults to desktop preview (the OpenXR-OSX streaming runtime initializes
# OpenXR on desktop, so is_initialized() can't be the fallback signal). --xr overrides.

const LAKE_CENTER := Vector3(0, 0, -10)
const HANDS := ["left", "right"]
# Shown on the intro card so the running build is identifiable in-headset.
const BUILD_TAG := "v3 · 2026-07-30"

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
var beam: MeshInstance3D
var reeds: Array[Node3D] = []

var audio: SfxPool
var ripples: RippleField
var flock: SwanFlock
var music: MusicDirector
var mood: MoodKit
var conductor: Conductor
var fireflies: FireflyField
var weather: WeatherKit
var fireworks: FireworkShow
var fishes: FishSchool
var constellation: CygnusPuzzle
var nest: SwanNest
var title: TitleCards
var menu: OrbMenu
var reflections: ReflectionRig
var perf: PerfGovernor
var hand_input  # HandInput — untyped: a new class_name isn't in the global class
                # cache until an editor pass, so don't depend on it resolving

var gather_on := false
var gather_point := Vector3(0, 0, -6.5)
var gather_held := 0.0
var finale_fired_this_gather := false
var attract_until := 0.0
var attract_point := Vector3.ZERO
var beam_alpha := 0.0

func _ready() -> void:
	_build_environment()
	_build_water()
	_build_dock()
	_build_shore()
	_build_beam()
	_init_xr_or_preview()
	hand_input = load("res://scripts/hand_input.gd").new(); add_child(hand_input)
	hand_input.setup(self)
	audio = SfxPool.new(); add_child(audio)
	ripples = RippleField.new(); add_child(ripples)
	ripples.water_mat = water_mat
	flock = SwanFlock.new(); add_child(flock)
	flock.main = self
	flock.spawn(8)
	music = MusicDirector.new(); add_child(music)
	music.finale_done.connect(_on_finale_done)
	conductor = Conductor.new(); add_child(conductor)
	conductor.setup(self)
	fireflies = FireflyField.new(); add_child(fireflies)
	fireflies.setup(self)
	weather = WeatherKit.new(); add_child(weather)
	weather.setup(self)
	for r in reeds:
		weather.register_reed(r)
	fireworks = FireworkShow.new(); add_child(fireworks)
	fireworks.setup(self)
	fishes = FishSchool.new(); add_child(fishes)
	fishes.setup(self)
	constellation = CygnusPuzzle.new(); add_child(constellation)
	constellation.setup(self)
	nest = SwanNest.new(); add_child(nest)
	nest.setup(self)
	reflections = ReflectionRig.new(); add_child(reflections)
	reflections.setup(self)
	perf = PerfGovernor.new(); add_child(perf)
	perf.setup(self)
	menu = OrbMenu.new(); add_child(menu)
	menu.setup(self)
	mood = MoodKit.new(); add_child(mood)
	mood.setup(self)
	mood.apply("night", true)
	title = TitleCards.new(); add_child(title)
	title.setup(self)

# ---------------------------------------------------------------- scene build

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
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 26.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.light_energy = 0.35
	add_child(moon)
	_aim_moon(Vector3(-0.22, 0.28, -0.93))

func _aim_moon(dir_to_moon: Vector3) -> void:
	dir_to_moon = dir_to_moon.normalized()
	sky_mat.set_shader_parameter("moon_dir", dir_to_moon)
	if water_mat:
		water_mat.set_shader_parameter("moon_dir", dir_to_moon)
	moon.look_at_from_position(Vector3.ZERO, -dir_to_moon, Vector3.UP)
	if beam and gather_on:
		_place_beam()

func moon_dir() -> Vector3:
	return Vector3(sky_mat.get_shader_parameter("moon_dir"))

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
	mi.layers = 1 | 2
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
	deck.position = Vector3(0, 0.30, 0.6)
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
	for i in 26:
		var a := rng.randf_range(0.0, TAU)
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.85:
			continue
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
		reed.set_meta("sway0", reed.rotation.z)
		add_child(reed)
		reeds.append(reed)

func _build_beam() -> void:
	beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.85
	cm.bottom_radius = 0.60
	cm.height = 10.0
	cm.radial_segments = 32
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	beam_mat = ShaderMaterial.new()
	beam_mat.shader = load("res://shaders/beam.gdshader")
	beam.material_override = beam_mat
	beam.visible = false
	add_child(beam)

func _place_beam() -> void:
	# beam base sits on the water at the gather point, shaft leans toward the moon
	var md := moon_dir()
	beam.position = gather_point + md * 5.0
	var basis := Basis()
	var y := md
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length() < 0.5:
		x = y.cross(Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	basis.x = x; basis.y = y; basis.z = z
	beam.transform.basis = basis
	# the shader needs the volume in world space to compute its soft falloff
	beam_mat.set_shader_parameter("beam_base", gather_point)
	beam_mat.set_shader_parameter("beam_axis", md)
	beam_mat.set_shader_parameter("beam_radius", 0.75)

# ---------------------------------------------------------------- XR / preview

func _init_xr_or_preview() -> void:
	var args := OS.get_cmdline_user_args()
	var force_preview: bool = ("--shot" in args) or ("--preview" in args) \
		or (OS.get_name() == "macOS" and not ("--xr" in args))
	var xr := XRServer.find_interface("OpenXR")
	if not force_preview and xr and xr.is_initialized():
		xr_active = true
		get_viewport().use_xr = true
		origin = XROrigin3D.new()
		origin.position = Vector3(0, 0.35, 0.6)
		add_child(origin)
		var cam := XRCamera3D.new()
		origin.add_child(cam)
		for hand in ["left_hand", "right_hand"]:
			var c := XRController3D.new()
			c.tracker = hand
			c.pose = "aim"
			origin.add_child(c)
			c.button_pressed.connect(_on_xr_button.bind(c, true))
			c.button_released.connect(_on_xr_button.bind(c, false))
			controllers.append(c)
	else:
		var rig := PreviewRig.new()
		rig.name = "PreviewRig"
		rig.main = self
		add_child(rig)
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
	reticle.layers = 4
	reticle.visible = false
	add_child(reticle)

func _on_xr_button(button: String, c: XRController3D, pressed: bool) -> void:
	var is_right := c.tracker == "right_hand"
	if pressed:
		match button:
			"trigger_click":
				title.skip_intro()
				if menu.try_tap(c):
					return
				if constellation.try_tap(c):
					return
				if nest.try_tap(c):
					return
				if is_right:
					var hit := _aim_hit(c)
					if hit != Vector3.INF:
						do_ripple(hit, 0.85)
				else:
					fireworks.try_manual(_aim_hit(c))
			"grip_click":
				var hit := _aim_hit(c)
				if hit != Vector3.INF:
					gather_point = hit
				set_gather(true)
			"ax_button":
				if is_right:
					mood.cycle()
				else:
					weather.cycle()
			"by_button":
				if is_right:
					trigger_finale()
				else:
					menu.toggle()
			"primary_click":
				if not menu.open:  # stick doubles as the baton tuner while the menu is up
					trigger_finale()  # thumbstick fallback so the finale is never unreachable
	else:
		if button == "grip_click":
			set_gather(false)

# With no controllers in hand there are no buttons, so pinch carries the verbs:
# right pinch = conduct (the trigger), left pinch = firework, both = gather.
# Without this, putting the controllers down left the piece completely inert.
func _bare_hand_gestures() -> void:
	var lb: bool = hand_input.bare("left")
	var rb: bool = hand_input.bare("right")
	if not (lb or rb):
		return
	var both: bool = lb and rb and hand_input.pinch_pressed("left") \
		and hand_input.pinch_pressed("right")
	if both != gather_on:
		if both:
			var g: Vector3 = _aim_hit_pose(hand_input.pose("right"))
			if g != Vector3.INF:
				gather_point = g
		set_gather(both)
	if both:
		return
	if rb and hand_input.pinch_just_pressed("right"):
		title.skip_intro()
		var hit: Vector3 = _aim_hit_pose(hand_input.pose("right"))
		if hit != Vector3.INF:
			do_ripple(hit, 0.85)
	if lb and hand_input.pinch_just_pressed("left"):
		fireworks.try_manual(_aim_hit_pose(hand_input.pose("left")))

func trigger_finale() -> void:
	if music.act4_active:
		return
	music.play_finale()
	fireworks.start_show()
	fishes.ballet()

func _on_finale_done() -> void:
	fireworks.stop_show(true)
	title.outro()

func _aim_hit(c: XRController3D) -> Vector3:
	return _aim_hit_pose(hand_input.pose(hand_of(c)))

func hand_of(c: XRController3D) -> String:
	return "right" if c.tracker == "right_hand" else "left"

# Single water-plane intersection used by every consumer — ripples, fireworks,
# gather point, reticle. Everything reads the arbitrated pose, so a bare hand and
# a held controller can never point somewhere different from what's drawn.
func _aim_hit_pose(t: Transform3D) -> Vector3:
	var from := t.origin
	var dir := -t.basis.z
	if dir.length() < 0.5 or dir.y > -0.02:
		return Vector3.INF
	var dist := from.y / -dir.y
	if dist > 60.0:
		return Vector3.INF
	return from + dir * dist

# ---------------------------------------------------------------- public verbs

func do_ripple(pos: Vector3, strength: float) -> void:
	ripples.burst(pos, strength)
	music.schedule_sfx(func(): audio.plop(pos, strength))
	fireflies.celebrate()
	if strength > 0.4:
		attract_point = pos
		attract_until = t + 6.0
		gather_point = pos

func set_gather(on: bool) -> void:
	if on == gather_on:
		return
	gather_on = on
	gather_held = 0.0
	finale_fired_this_gather = false
	if on:
		beam.visible = true
		_place_beam()
		flock.set_gather(true, gather_point)
		ripples.add(gather_point, 0.4)
	else:
		flock.set_gather(false, gather_point)

func water_height(x: float, z: float) -> float:
	return sin(x * 0.5 + t * 0.7) * 0.02 + cos(z * 0.4 + t * 0.55) * 0.02

func user_position() -> Vector3:
	# Floor-level reference (XR origin). NOT eye height — see head_transform().
	if xr_active and origin:
		return origin.global_position
	return Vector3(0, 0.35, 0.6)

func head_transform() -> Transform3D:
	# Actual eye pose, XR or preview. Anything spawned "in front of the user"
	# must use this: user_position() is floor-level in XR but was returning eye
	# height in preview, so head-relative UI landed ~1.6m too high on desktop.
	if xr_active and origin:
		for c in origin.get_children():
			if c is XRCamera3D:
				return (c as XRCamera3D).global_transform
		return Transform3D(Basis(), origin.global_position + Vector3(0, 1.35, 0))
	var pv: Node = get_node_or_null("PreviewRig")
	if pv:
		var cam: Node = pv.get_node_or_null("Camera3D")
		if cam:
			return (cam as Camera3D).global_transform
	return Transform3D(Basis(), Vector3(0, 1.6, 0.6))

func _process(delta: float) -> void:
	t += delta
	water_mat.set_shader_parameter("u_time", t)
	sky_mat.set_shader_parameter("u_time", t)
	ripples.tick(t)
	var e: float = music.energy
	water_mat.set_shader_parameter("music_energy", e)
	var target_a := 0.16 if gather_on else 0.0
	beam_alpha = lerpf(beam_alpha, target_a, delta * 3.0)
	beam_mat.set_shader_parameter("alpha", beam_alpha * (1.0 + e * 0.7))
	if beam_alpha < 0.005 and not gather_on:
		beam.visible = false
	if gather_on:
		gather_held += delta
		if gather_held > 4.0 and not finale_fired_this_gather and not music.act4_active:
			finale_fired_this_gather = true
			trigger_finale()
	if xr_active:
		_bare_hand_gestures()
		var best := Vector3.INF
		for hand in HANDS:
			if not hand_input.active(hand):
				continue
			var h: Vector3 = _aim_hit_pose(hand_input.pose(hand))
			if h != Vector3.INF:
				best = h
				break
		if best != Vector3.INF and not menu.open:
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
