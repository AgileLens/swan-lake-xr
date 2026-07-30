class_name OrbMenu
extends Node
# Floating settings orbs (left Y toggles): aim + right trigger cycles a setting.
# Everything Alex might want to taste-test lives here.

var main  # SwanLakeMain
var root: Node3D
var open := false
var orbs: Array[MeshInstance3D] = []
var labels: Array[Label3D] = []
var defs: Array[Dictionary] = []

func setup(m) -> void:
	main = m
	defs = [
		{"name": "Swans", "get": func(): return main.flock.style_name(),
			"cycle": func(): main.flock.cycle_style()},
		{"name": "Mood", "get": func(): return main.mood.current,
			"cycle": func(): main.mood.cycle()},
		{"name": "Weather", "get": func(): return main.weather.current,
			"cycle": func(): main.weather.cycle()},
		{"name": "Reflections", "get": func(): return main.reflections.mode_name(),
			"cycle": func(): main.reflections.cycle()},
		{"name": "Shadows", "get": func(): return "on" if main.moon.shadow_enabled else "off",
			"cycle": func(): main.moon.shadow_enabled = not main.moon.shadow_enabled},
		{"name": "Sparkles", "get": func(): return ["low", "med", "high"][main.conductor.sparkle_level],
			"cycle": func(): main.conductor.set_sparkle_level((main.conductor.sparkle_level + 1) % 3)},
		{"name": "FPS HUD", "get": func(): return "on" if main.perf.hud_on else "off",
			"cycle": func(): main.perf.set_hud(not main.perf.hud_on)},
	]

func toggle() -> void:
	open = not open
	if open:
		_build()
	elif root:
		root.queue_free()
		root = null

func _build() -> void:
	if root:
		root.queue_free()
	root = Node3D.new()
	var head: Vector3 = main.user_position() + Vector3(0, 1.35, 0)
	root.position = head + Vector3(0, 0, -1.25)
	main.add_child(root)
	orbs.clear(); labels.clear()
	for i in defs.size():
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.055; sm.height = 0.11
		orb.mesh = sm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.85, 0.9, 1.0, 0.85)
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.emission_enabled = true
		mm.emission = Color(0.5, 0.7, 1.0)
		mm.emission_energy_multiplier = 0.6
		orb.material_override = mm
		orb.position = Vector3((i - (defs.size() - 1) * 0.5) * 0.24, 0, 0)
		root.add_child(orb)
		orbs.append(orb)
		var l := Label3D.new()
		l.font_size = 15
		l.pixel_size = 0.0035
		l.position = orb.position + Vector3(0, -0.11, 0)
		root.add_child(l)
		labels.append(l)
	_refresh()

func _refresh() -> void:
	for i in defs.size():
		labels[i].text = "%s\n[%s]" % [defs[i].name, str(defs[i].get.call())]

func aimed_orb(c: XRController3D) -> int:
	if not open or root == null:
		return -1
	var from := c.global_position
	var dir := -c.global_transform.basis.z
	for i in orbs.size():
		var to: Vector3 = orbs[i].global_position
		if dir.angle_to((to - from).normalized()) < deg_to_rad(4.5) and from.distance_to(to) < 4.0:
			return i
	return -1

func try_tap(c: XRController3D) -> bool:
	var i := aimed_orb(c)
	if i < 0:
		return false
	defs[i].cycle.call()
	main.audio.play2d("chime_%d" % (i % 7 + 1), -12.0, 1.4)
	_refresh()
	return true

func _process(_d: float) -> void:
	if not open or root == null:
		return
	for i in orbs.size():
		var hot := false
		for c in main.controllers:
			if aimed_orb(c) == i:
				hot = true
				break
		var mm: StandardMaterial3D = orbs[i].material_override
		mm.emission_energy_multiplier = 2.2 if hot else 0.6
		orbs[i].scale = Vector3.ONE * (1.3 if hot else 1.0)
