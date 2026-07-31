class_name FireflyField
extends Node
# Synesthetic fireflies: color/pattern/light respond to conducting, music, gather, and events.

var main  # SwanLakeMain
var particles: GPUParticles3D
var pmat: ParticleProcessMaterial
var draw_mat: ShaderMaterial
var attractor: GPUParticlesAttractorSphere3D
var accent_color := Color(1.0, 0.75, 0.9)
var _celebrate := 0.0
# Was 130 — the research brief on mobile-XR GPU headroom flagged this as the
# single best wow-per-hour lever: thousands of small additively-blended sprites
# are genuinely GPU-costly on tile hardware (overdraw, not triangle count), and
# it's the most headset-legible "this headset is doing something special"
# moment for a night scene. Perf-governable: the last tier the governor sheds.
const AMOUNT_TIERS := [130, 600, 1500, 2500]
var amount_tier := 3

func setup(m) -> void:
	main = m
	particles = GPUParticles3D.new()
	particles.amount = AMOUNT_TIERS[amount_tier]
	particles.lifetime = 7.0
	particles.preprocess = 4.0
	pmat = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(11, 1.2, 9)
	pmat.gravity = Vector3.ZERO
	pmat.initial_velocity_min = 0.05
	pmat.initial_velocity_max = 0.22
	pmat.turbulence_enabled = true
	pmat.turbulence_noise_strength = 0.35
	pmat.turbulence_noise_scale = 1.6
	pmat.scale_min = 0.5
	pmat.scale_max = 1.0
	particles.process_material = pmat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	# Custom shader (was StandardMaterial3D): fireflies and snow were sharing the
	# exact same visual language — a small pale radial-glow billboard, just
	# differently colored. Alex + Dax: "fireflies should have a pulsing yellow
	# glow and turn on and off, in time to the music." A smooth emission-color
	# lerp can't do a real blink; this needs per-particle phase logic.
	draw_mat = ShaderMaterial.new()
	draw_mat.shader = load("res://shaders/firefly.gdshader")
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5); grad.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	grad.gradient = g
	draw_mat.set_shader_parameter("albedo_tex", grad)
	draw_mat.set_shader_parameter("proximity_fade_distance", 0.35)
	quad.material = draw_mat
	particles.draw_pass_1 = quad
	particles.position = Vector3(0, 1.0, -6)
	main.add_child(particles)
	attractor = GPUParticlesAttractorSphere3D.new()
	attractor.radius = 3.5
	attractor.strength = 0.0
	attractor.attenuation = 1.5
	main.add_child(attractor)

func set_mood_colors(_base: Color, accent: Color) -> void:
	accent_color = accent
	# warm_color stays fixed (yellow firefly glow) regardless of mood — only the
	# conducting-energy accent shifts per mood, same as before
	draw_mat.set_shader_parameter("accent_color", accent)

func celebrate() -> void:
	_celebrate = 3.0

func step_down_amount() -> bool:
	# Called by the perf governor. Returns false once already at the floor, so
	# the governor knows to move on to the next thing to shed.
	if amount_tier <= 0:
		return false
	amount_tier -= 1
	particles.amount = AMOUNT_TIERS[amount_tier]
	return true

func _process(delta: float) -> void:
	_celebrate = maxf(_celebrate - delta, 0.0)
	var ce: float = main.conductor.conduct_energy if main.conductor else 0.0
	var me: float = main.music.energy
	var drive := clampf(ce * 0.85 + me * 0.45 + _celebrate * 0.33, 0.0, 1.3)
	# Pure warm-yellow at rest; conducting hard shifts toward the mood's accent
	# color, same "you're doing this" legibility as before — just layered on
	# top of a blink instead of replacing it.
	draw_mat.set_shader_parameter("accent_mix", clampf(ce * 1.2, 0.0, 1.0))
	draw_mat.set_shader_parameter("drive", drive)
	draw_mat.set_shader_parameter("beat_phase", main.music.beat_phase())
	particles.speed_scale = 0.75 + drive * 1.1
	pmat.turbulence_noise_strength = 0.32 + drive * 0.5
	# attract toward baton tip while conducting hard, or into the moonbeam during gather
	if main.gather_on:
		attractor.global_position = Vector3(main.gather_point.x, 2.2, main.gather_point.z)
		attractor.strength = -4.0
		attractor.radius = 4.5
	elif ce > 0.12:
		# Alex in-headset: "am I conducting the fireflies, I can't tell?" — the old
		# gate (ce > 0.4) plus a 2.8m radius meant a gentle gesture did nothing and
		# a hard one only tugged whatever happened to be within arm's reach. The pull
		# now starts as soon as the baton moves and reaches far enough to actually
		# catch some, so cause and effect are legible.
		attractor.global_position = main.conductor.tip_position()
		attractor.strength = -(1.5 + 7.5 * ce)
		attractor.radius = 5.5 + 2.5 * ce
	else:
		attractor.strength = 0.0
