class_name FireflyField
extends Node
# Synesthetic fireflies: color/pattern/light respond to conducting, music, gather, and events.

var main  # SwanLakeMain
var particles: GPUParticles3D
var pmat: ParticleProcessMaterial
var draw_mat: StandardMaterial3D
var attractor: GPUParticlesAttractorSphere3D
var base_color := Color(0.55, 0.85, 1.0)
var accent_color := Color(1.0, 0.75, 0.9)
var _celebrate := 0.0

func setup(m) -> void:
	main = m
	particles = GPUParticles3D.new()
	particles.amount = 130
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
	draw_mat = StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5); grad.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	grad.gradient = g
	draw_mat.albedo_texture = grad
	draw_mat.albedo_color = Color(1, 1, 1, 0.34)
	draw_mat.emission_enabled = true
	draw_mat.emission = base_color
	draw_mat.emission_energy_multiplier = 1.6
	quad.material = draw_mat
	particles.draw_pass_1 = quad
	particles.position = Vector3(0, 1.0, -6)
	main.add_child(particles)
	attractor = GPUParticlesAttractorSphere3D.new()
	attractor.radius = 3.5
	attractor.strength = 0.0
	attractor.attenuation = 1.5
	main.add_child(attractor)

func set_mood_colors(base: Color, accent: Color) -> void:
	base_color = base
	accent_color = accent

func celebrate() -> void:
	_celebrate = 3.0

func _process(delta: float) -> void:
	_celebrate = maxf(_celebrate - delta, 0.0)
	var ce: float = main.conductor.conduct_energy if main.conductor else 0.0
	var me: float = main.music.energy
	var drive := clampf(ce * 0.85 + me * 0.45 + _celebrate * 0.33, 0.0, 1.3)
	draw_mat.emission = base_color.lerp(accent_color, clampf(ce * 1.2, 0, 1))
	draw_mat.emission_energy_multiplier = 1.3 + drive * 3.4
	particles.speed_scale = 0.75 + drive * 1.1
	pmat.turbulence_noise_strength = 0.32 + drive * 0.5
	# attract toward baton tip while conducting hard, or into the moonbeam during gather
	if main.gather_on:
		attractor.global_position = Vector3(main.gather_point.x, 2.2, main.gather_point.z)
		attractor.strength = -4.0
		attractor.radius = 4.5
	elif ce > 0.4:
		attractor.global_position = main.conductor.tip_position()
		attractor.strength = -2.2 * ce
		attractor.radius = 2.8
	else:
		attractor.strength = 0.0
