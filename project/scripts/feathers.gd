class_name FeatherFall
extends Node
# White feathers drifting down at the curtain, more of them for a warmer reception.
var main
var p: GPUParticles3D

func setup(m) -> void:
	main = m
	p = GPUParticles3D.new()
	p.amount = 240
	p.lifetime = 11.0
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 30, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 0.5, 9)
	pm.gravity = Vector3(0, -0.32, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.1
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.7
	pm.turbulence_noise_scale = 1.2
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.albedo_color = Color(0.96, 0.96, 0.92)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.gradient = g
	mat.albedo_texture = tex
	q.material = mat
	p.draw_pass_1 = q
	p.position = Vector3(0, 9, -5)
	main.add_child(p)

func start(tier: int) -> void:
	p.amount = [90, 150, 200, 240][clampi(tier, 0, 3)]
	p.emitting = true
	get_tree().create_timer(26.0).timeout.connect(func(): p.emitting = false)
