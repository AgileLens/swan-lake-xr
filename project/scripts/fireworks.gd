class_name FireworkShow
extends Node
# Rockets + radial burst particles + crackle. Manual launches and an Act-4 barrage.

var main  # SwanLakeMain
var palette: Array = [Color(0.7, 0.85, 1.0), Color(1.0, 0.8, 0.5), Color(0.9, 0.6, 1.0)]
var rockets: Array[Dictionary] = []
var bursts: Array[GPUParticles3D] = []
var show_on := false
var show_timer := 0.0
var manual_cooldown := 0.0
var finale_barrage_left := 0

func setup(m) -> void:
	main = m
	main.water_mat.set_shader_parameter("glint_pulse", 0.0)
	for i in 5:
		var p := GPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = 260
		p.lifetime = 2.1
		p.explosiveness = 1.0
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.1
		pm.spread = 180.0
		pm.direction = Vector3(0, 1, 0)
		pm.initial_velocity_min = 4.5
		pm.initial_velocity_max = 8.5
		pm.gravity = Vector3(0, -1.3, 0)
		pm.damping_min = 1.4
		pm.damping_max = 2.2
		pm.scale_min = 0.5
		pm.scale_max = 1.1
		var sc := CurveTexture.new(); var cv := Curve.new()
		cv.add_point(Vector2(0, 1)); cv.add_point(Vector2(0.7, 0.55)); cv.add_point(Vector2(1, 0))
		sc.curve = cv
		pm.scale_curve = sc
		p.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(0.14, 0.14)
		var m2 := StandardMaterial3D.new()
		m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m2.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var grad := GradientTexture2D.new()
		grad.fill = GradientTexture2D.FILL_RADIAL
		grad.fill_from = Vector2(0.5, 0.5); grad.fill_to = Vector2(0.5, 0.0)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
		grad.gradient = g
		m2.albedo_texture = grad
		m2.emission_enabled = true
		m2.emission_energy_multiplier = 5.5
		quad.material = m2
		p.draw_pass_1 = quad
		main.add_child(p)
		bursts.append(p)

func set_palette(colors: Array) -> void:
	palette = colors

func launch(at: Vector3) -> void:
	var start := Vector3(at.x, 0.0, at.z)
	var apex := Vector3(at.x + randf_range(-1, 1), randf_range(7.5, 12.5), at.z + randf_range(-1, 1))
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09; sm.height = 0.18
	head.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.emission_enabled = true
	mm.emission = Color(1, 0.95, 0.8)
	mm.emission_energy_multiplier = 8.0
	head.material_override = mm
	head.position = start
	main.add_child(head)
	rockets.append({"node": head, "t": 0.0, "dur": randf_range(1.0, 1.35), "a": start, "b": apex})
	main.audio.play3d("whoosh", start, -6.0)

func _burst_at(pos: Vector3) -> void:
	for p in bursts:
		if not p.emitting:
			var col: Color = palette[randi() % palette.size()]
			var m2: StandardMaterial3D = (p.draw_pass_1 as QuadMesh).material
			m2.emission = col
			m2.albedo_color = Color(col.r, col.g, col.b, 0.8)
			p.global_position = pos
			p.restart()
			break
	main.audio.play3d("crackle", pos, -2.0)
	main.water_mat.set_shader_parameter("glint_pulse", 1.6)
	main.ripples.add(Vector3(pos.x, 0, pos.z), 0.10)
	main.fireflies.celebrate()

func start_show() -> void:
	show_on = true
	show_timer = 0.5

func stop_show(with_barrage := true) -> void:
	show_on = false
	if with_barrage:
		finale_barrage_left = 5

func _process(delta: float) -> void:
	manual_cooldown = maxf(manual_cooldown - delta, 0.0)
	var pulse_v = main.water_mat.get_shader_parameter("glint_pulse")
	var pulse: float = pulse_v if pulse_v != null else 0.0
	if pulse > 0.0:
		main.water_mat.set_shader_parameter("glint_pulse", maxf(pulse - delta * 1.8, 0.0))
	var done: Array[Dictionary] = []
	for r in rockets:
		r.t += delta
		var u: float = clampf(r.t / r.dur, 0.0, 1.0)
		var ease_u := 1.0 - pow(1.0 - u, 2.2)
		var n: MeshInstance3D = r.node
		n.position = r.a.lerp(r.b, ease_u)
		if r.t > r.dur * 0.25 and randf() < 0.5:
			main.conductor.sparkles.global_position = n.position  # borrow trail for cheap rocket sparks
		if u >= 1.0:
			_burst_at(r.b)
			n.queue_free()
			done.append(r)
	for r in done:
		rockets.erase(r)
	if show_on and main.music.act4_active:
		show_timer -= delta
		if show_timer <= 0.0 and main.music.energy > 0.30:
			show_timer = randf_range(1.5, 2.7)
			launch(Vector3(randf_range(-11, 11), 0, randf_range(-26, -13)))
	if finale_barrage_left > 0:
		show_timer -= delta
		if show_timer <= 0.0:
			show_timer = 0.42
			finale_barrage_left -= 1
			launch(Vector3(randf_range(-12, 12), 0, randf_range(-24, -12)))

func try_manual(at: Vector3) -> void:
	if manual_cooldown <= 0.0 and at != Vector3.INF:
		manual_cooldown = 1.1
		launch(at)
