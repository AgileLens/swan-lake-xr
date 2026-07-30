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
		{"name": "Corps", "get": func(): return main.megaflock.level_name(),
			"cycle": func(): main.megaflock.cycle()},
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
		{"name": "Baton", "get": func(): return main.conductor.pose_label(),
			"cycle": func(): main.conductor.cycle_pose()},
		{"name": "SFX time", "get": func(): return main.music.timing_mode_name(),
			"cycle": func(): main.music.cycle_timing()},
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
	var head: Transform3D = main.head_transform()
	root.position = head.origin
	# yaw-only: the orb arc should open where the user is facing, but stay level
	# even if they're looking up or down when they press the button
	# A node's own -Z is its forward, so aligning it with the head's forward
	# (-basis.z) means yaw = atan2(basis.z.x, basis.z.z) — negating here too
	# would spin the arc a half-turn behind the user.
	root.rotation.y = atan2(head.basis.z.x, head.basis.z.z)
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
		orb.position = _slot(i)
		root.add_child(orb)
		orbs.append(orb)
		var l := Label3D.new()
		l.font_size = 15
		l.pixel_size = 0.003
		# Two staggered rows: billboarded labels don't shrink with the arc's
		# perspective, so neighbors collide horizontally on a single row.
		var row: float = -0.115 if i % 2 == 0 else -0.235
		l.position = orb.position + Vector3(0, row, 0)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(l)
		labels.append(l)
	_refresh()

func _slot(i: int) -> Vector3:
	# Arc the orbs around the head at a fixed radius — a flat row this wide
	# (9 settings) pushes the end orbs off to the side and out of easy aim.
	const RADIUS := 1.25
	const STEP_DEG := 12.5
	var a := deg_to_rad((float(i) - float(defs.size() - 1) * 0.5) * STEP_DEG)
	return Vector3(sin(a) * RADIUS, 0, -cos(a) * RADIUS)

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

var _refresh_t := 0.0

func _process(_d: float) -> void:
	if not open or root == null:
		return
	# throttled label refresh so live-tuned values (baton stick-dial) read out in place
	_refresh_t += _d
	if _refresh_t > 0.2:
		_refresh_t = 0.0
		_refresh()
	for i in orbs.size():
		var hot := false
		for c in main.controllers:
			if aimed_orb(c) == i:
				hot = true
				break
		var mm: StandardMaterial3D = orbs[i].material_override
		mm.emission_energy_multiplier = 2.2 if hot else 0.6
		orbs[i].scale = Vector3.ONE * (1.3 if hot else 1.0)
