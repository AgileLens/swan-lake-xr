class_name SwanLakeMain
extends Node3D
# Swan Lake XR v2 — orchestrator. Scene + systems built in code.
# macOS defaults to desktop preview (the OpenXR-OSX streaming runtime initializes
# OpenXR on desktop, so is_initialized() can't be the fallback signal). --xr overrides.

const LAKE_CENTER := Vector3(0, 0, -10)
const HANDS := ["left", "right"]
# Shown on the intro card so the running build is identifiable in-headset.
const BUILD_TAG := "v5 · 2026-11-04"

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
var launch_menu: SwanLaunchMenu
var megaflock: MegaFlock
var reflections: ReflectionRig
var perf: PerfGovernor
var program: ConductorsProgram
var stand: MusicStand
var rainbow: Rainbow
var storm: StormKit
var feathers: FeatherFall
var env_mat: ShaderMaterial
var lead_ring_until := 0.0
var hand_input  # HandInput — untyped: a new class_name isn't in the global class
                # cache until an editor pass, so don't depend on it resolving

var gather_on := false
var gather_point := Vector3(0, 0, -6.5)
var gather_held := 0.0
var finale_fired_this_gather := false
var attract_until := 0.0
var attract_point := Vector3.ZERO
var beam_alpha := 0.0
var mesh_hands_visible := true
var real_hands_visible := false
var visual_style_index := 0
const SAVE_PATH := "user://swan_program.cfg"

func _ready() -> void:
	_build_environment()
	_build_water()
	_build_scenery()
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
	megaflock = MegaFlock.new(); add_child(megaflock)
	megaflock.setup(self)
	music = MusicDirector.new(); add_child(music)
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
	rainbow = Rainbow.new(); add_child(rainbow)
	rainbow.setup(self)
	storm = StormKit.new(); add_child(storm)
	storm.setup(self)
	feathers = FeatherFall.new(); add_child(feathers)
	feathers.setup(self)
	reflections = ReflectionRig.new(); add_child(reflections)
	reflections.setup(self)
	perf = PerfGovernor.new(); add_child(perf)
	perf.setup(self)
	menu = OrbMenu.new(); add_child(menu)
	menu.setup(self)
	mood = MoodKit.new(); add_child(mood)
	mood.setup(self)
	mood.apply("predawn", true)
	title = TitleCards.new(); add_child(title)
	title.setup(self)
	stand = MusicStand.new(); add_child(stand)
	stand.setup(self)
	program = ConductorsProgram.new(); add_child(program)
	program.setup(self)
	_launch_mode()

# ---------------------------------------------------------------- scene build

func _build_environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	# REVERTED to 64. When the sky got a hard vertical seam after adding clouds+
	# aurora, I wrongly suspected radiance resolution and bumped this to 256 —
	# a 16x increase in the per-frame radiance-capture pixel count (256²×6 vs
	# 64²×6), recomputed every frame because of PROCESS_MODE_REALTIME below. The
	# seam's real cause was atan(d.x,d.z) wrapping at ±π (see sky.gdshader) — I
	# fixed THAT the same night but never reverted this, and it went unnoticed on
	# desktop (M1 Max has GPU headroom to spare) until live on-device testing on
	# the actual Swan hit fps=37 with the perf governor's ENTIRE ladder (corps,
	# fireflies, reflections, shadows, sparkles, MSAA) already exhausted and
	# still no recovery — this uncapped, ungoverned cost is the likely reason.
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.012
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.3
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

func _launch_mode() -> void:
	# Only one of these runs. Everything else is a developer tool that never ships a flow.
	var args := OS.get_cmdline_user_args()
	for mode in [["--swanlab", "res://scripts/swan_lab.gd"], ["--autotest", "res://scripts/autotest.gd"],
			["--stills", "res://scripts/stills.gd"], ["--clip", "res://scripts/clips.gd"]]:
		for a in args:
			if a == mode[0] or a.begins_with(mode[0] + "="):
				var tool: Node = load(mode[1]).new()
				add_child(tool)
				tool.setup(self)
				return
	# The real thing: title art and an explicit opening menu over a sleeping flock.
	flock.put_to_sleep()
	launch_menu = SwanLaunchMenu.new(); add_child(launch_menu); launch_menu.setup(self)

func has_saved_program() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func saved_program_index() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK: return 0
	return clampi(int(cfg.get_value("program", "movement", 0)), 0, ProgramData.MOVEMENTS.size() - 1)

func save_program_index(index: int) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest") or arg.begins_with("--stills") or arg.begins_with("--clip") or arg == "--swanlab":
			return
	var cfg := ConfigFile.new(); cfg.set_value("program", "movement", index)
	cfg.set_value("presentation", "style", visual_style_index)
	cfg.set_value("presentation", "mesh_hands", mesh_hands_visible)
	cfg.save(SAVE_PATH)

func cycle_visual_style() -> void:
	visual_style_index = SwanPresentation.next_style(visual_style_index)
	apply_visual_style()

func apply_visual_style() -> void:
	match visual_style_index:
		0: env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_white = 2.2; env.adjustment_enabled = false
		1: env.tonemap_mode = Environment.TONE_MAPPER_LINEAR; env.tonemap_white = 1.6; env.adjustment_enabled = true; env.adjustment_contrast = 1.25; env.adjustment_saturation = 1.18
		2: env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_white = 2.5; env.adjustment_enabled = true; env.adjustment_contrast = 0.84; env.adjustment_saturation = 0.80
		3: env.tonemap_mode = Environment.TONE_MAPPER_LINEAR; env.tonemap_white = 2.0; env.adjustment_enabled = true; env.adjustment_contrast = 1.10; env.adjustment_saturation = 0.92
		4: env.tonemap_mode = Environment.TONE_MAPPER_LINEAR; env.tonemap_white = 2.0; env.adjustment_enabled = true; env.adjustment_contrast = 1.08; env.adjustment_saturation = 0.08
	# Environment-only presets: intentionally safe on the Mobile renderer.

func haptic_controller(c: XRController3D, strength := 0.35, duration := 0.04) -> void:
	if c and xr_active:
		c.trigger_haptic_pulse("haptic", 0.0, clampf(strength, 0.0, 1.0), duration, 0.0)

func _build_water() -> void:
	var mesh := PlaneMesh.new()
	# Runs well past every shoreline, so the lake has no edge to see.
	mesh.size = Vector2(320, 320)
	mesh.subdivide_width = 100
	mesh.subdivide_depth = 100
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = water_mat
	mi.position = Vector3(0, 0, -40)
	mi.layers = 1 | 2
	add_child(mi)

func _build_scenery() -> void:
	# Dock, banks, forest and reeds come from assets_src/make_env.py as one vertex-colored
	# set, so the shore holds up in daylight and stays a handful of draw calls.
	var scene: PackedScene = load("res://assets/env/env.glb")
	var inst: Node3D = scene.instantiate()
	env_mat = ShaderMaterial.new()
	env_mat.shader = load("res://shaders/env.gdshader")
	env_mat.set_shader_parameter("night_fill", 0.0)  # tweens read this back, so it can't be unset
	_dress_env(inst)
	add_child(inst)

func _dress_env(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.material_override = env_mat
		# Only the dock is close enough to cast a shadow anyone would notice.
		if not mi.name.begins_with("Dock"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children(true):
		_dress_env(c)

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
	var dev_mode := false
	for a in args:
		if a.begins_with("--autotest") or a.begins_with("--stills") or a.begins_with("--clip") or a == "--swanlab":
			dev_mode = true
	var force_preview: bool = ("--shot" in args) or ("--preview" in args) or dev_mode \
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
		haptic_controller(c, 0.28, 0.035)
		match button:
			"trigger_click":
				press_primary(hand_input.pose(hand_of(c)), is_right)
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
					program.next_movement()
				else:
					menu.toggle()
			"primary_click":
				if not menu.open:  # stick doubles as the baton tuner while the menu is up
					program.next_movement()
	else:
		if button == "grip_click":
			set_gather(false)

# With no controllers in hand there are no buttons, so pinch carries the verbs:
# right pinch = conduct (the trigger), left pinch = firework, both = gather.
# Without this, putting the controllers down left the piece completely inert.
# Trigger, right pinch and left-click all arrive here, so every input conducts the same.
func press_primary(pose: Transform3D, is_right: bool) -> void:
	title.skip_intro()
	if launch_menu and launch_menu.open and launch_menu.try_tap(pose):
		return
	if stand.try_tap(pose):
		return
	if menu.try_tap(pose):
		return
	if constellation.try_tap(pose):
		return
	if nest.try_tap(pose):
		return
	if is_right:
		var hit := _aim_hit_pose(pose)
		if hit != Vector3.INF:
			do_ripple(hit, 0.85)
		program.on_downbeat(0.6, true)
	else:
		fireworks.try_manual(_aim_hit_pose(pose))

func baton_aim_pose() -> Transform3D:
	# The pose a press acts from. Same value the visuals use.
	if xr_active:
		return hand_input.pose("right")
	var h := head_transform()
	var tip: Vector3 = conductor.tip_position()
	if tip == Vector3.ZERO:
		return h
	return Transform3D(Basis.looking_at((tip - h.origin).normalized(), Vector3.UP), h.origin)

func baton_water_point() -> Vector3:
	return _aim_hit_pose(baton_aim_pose())

func set_reticle_lead(p: Vector3) -> void:
	# The Regatta's lead point shows on the water, so you can see what the line is chasing.
	lead_ring_until = t + 0.25
	reticle.visible = true
	reticle.position = Vector3(p.x, water_height(p.x, p.z) + 0.03, p.z)

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
		press_primary(hand_input.pose("right"), true)
	if lb and hand_input.pinch_just_pressed("left"):
		press_primary(hand_input.pose("left"), false)

func trigger_finale() -> void:
	program.next_movement()

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
	sky_mat.set_shader_parameter("music_energy", music.energy)
	ripples.tick(t)
	var e: float = music.energy
	water_mat.set_shader_parameter("music_energy", e)
	flock.attract_active = t < attract_until
	flock.attract_point = attract_point
	var target_a := 0.16 if gather_on else 0.0
	beam_alpha = lerpf(beam_alpha, target_a, delta * 3.0)
	beam_mat.set_shader_parameter("alpha", beam_alpha * (1.0 + e * 0.7))
	if beam_alpha < 0.005 and not gather_on:
		beam.visible = false
	if gather_on:
		gather_held += delta
		# After the program, a long gather still calls for the fireworks, as it always has.
		if gather_held > 4.0 and not finale_fired_this_gather and program.state == ConductorsProgram.State.FREE:
			finale_fired_this_gather = true
			program.encore()
	if xr_active:
		_bare_hand_gestures()
		if t < lead_ring_until:
			return
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

func set_reticle_preview(pos: Vector3, show: bool) -> void:
	reticle.visible = show
	if show:
		reticle.position = Vector3(pos.x, water_height(pos.x, pos.z) + 0.03, pos.z)
