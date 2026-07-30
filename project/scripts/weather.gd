class_name WeatherKit
extends Node
# Clear / Snow / Rain / Breeze. Rain feeds real ripples into the water; breeze raises
# the wavelets and sways the reeds; loops fade via SfxPool.

var main  # SwanLakeMain
var order := ["clear", "snow", "rain", "breeze"]
var current := "clear"
var snow: GPUParticles3D
var rain: GPUParticles3D
var mist: GPUParticles3D
var rain_timer := 0.0
var reeds: Array[Node3D] = []

func setup(m) -> void:
	main = m
	snow = _make_particles(700, 9.0, Vector3(16, 7, 16), Vector3(0, -0.6, 0), 0.024, Color(1, 1, 1, 0.85), 0.5)
	snow.position = Vector3(0, 6, -8)
	var spm: ParticleProcessMaterial = snow.process_material
	spm.turbulence_enabled = true
	spm.turbulence_noise_strength = 0.8
	spm.turbulence_noise_scale = 0.9
	rain = _make_particles(900, 1.1, Vector3(14, 1, 12), Vector3(0, -11.0, 0), 0.012, Color(0.7, 0.8, 1.0, 0.5), 0.0)
	rain.position = Vector3(0, 7, -7)
	var rpm: ParticleProcessMaterial = rain.process_material
	rpm.emission_box_extents = Vector3(14, 0.5, 12)
	var rq: QuadMesh = rain.draw_pass_1
	rq.size = Vector2(0.006, 0.30)
	var rm: StandardMaterial3D = rq.material
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y  # vertical streaks
	mist = _make_particles(60, 12.0, Vector3(14, 1.5, 12), Vector3(0.7, 0.0, 0.15), 2.2, Color(0.75, 0.8, 0.9, 0.045), 0.2)
	mist.position = Vector3(0, 1.2, -9)
	for p in [snow, rain, mist]:
		p.emitting = false

func register_reed(r: Node3D) -> void:
	reeds.append(r)

func _make_particles(amount: int, life: float, box: Vector3, gravity: Vector3, size: float, color: Color, vel: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life * 0.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.gravity = gravity
	pm.initial_velocity_min = vel * 0.4
	pm.initial_velocity_max = vel
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5); grad.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	grad.gradient = g
	m.albedo_texture = grad
	m.albedo_color = color
	quad.material = m
	p.draw_pass_1 = quad
	main.add_child(p)
	return p

func cycle() -> String:
	var i := (order.find(current) + 1) % order.size()
	set_weather(order[i])
	return current

func set_weather(name: String) -> void:
	current = name
	snow.emitting = name == "snow"
	rain.emitting = name == "rain"
	mist.emitting = name == "breeze"
	var amp := 1.0
	match name:
		"breeze": amp = 1.65
		"rain": amp = 1.3
		"snow": amp = 0.85
	main.water_mat.set_shader_parameter("wave_amp", amp)
	match name:
		"rain": main.audio.set_weather_loop("rain_loop", -20.0)
		"breeze": main.audio.set_weather_loop("wind_loop", -19.0)
		"snow": main.audio.set_weather_loop("wind_loop", -27.0)
		_: main.audio.set_weather_loop("")

func _process(delta: float) -> void:
	if current == "rain":
		rain_timer -= delta
		if rain_timer <= 0.0:
			rain_timer = 0.16
			var p := Vector3(randf_range(-10, 10), 0, randf_range(-16, -1))
			main.ripples.add(p, randf_range(0.025, 0.06))
	if current == "breeze" or current == "snow":
		var t: float = main.t
		for i in reeds.size():
			var r := reeds[i]
			var base: float = r.get_meta("sway0", 0.0)
			r.rotation.z = base + sin(t * 1.7 + float(i) * 1.3) * (0.09 if current == "breeze" else 0.03)
