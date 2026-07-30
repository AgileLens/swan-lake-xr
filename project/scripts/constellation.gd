class_name CygnusPuzzle
extends Node
# Easter-egg puzzle: light the seven stars of Cygnus (the Swan) with the baton.
# Each lit star plays a rising pentatonic chime; completing it draws the constellation,
# fires a shooting star, triggers a swan flyby, and wakes the nest egg.

var main  # SwanLakeMain
var stars: Array[MeshInstance3D] = []
var lit: Array[bool] = []
var done := false
var lines_drawn := false
# Cygnus cross, roughly: Deneb tail, Sadr center, Albireo head, wing tips + inner wings
var dirs := [
	Vector3(-0.10, 0.62, -0.72),  # Deneb
	Vector3(-0.02, 0.50, -0.80),  # Sadr (hub)
	Vector3(0.10, 0.34, -0.90),   # Albireo (head, golden)
	Vector3(-0.30, 0.52, -0.72),  # Gienah (wing L)
	Vector3(0.24, 0.55, -0.74),   # Delta (wing R)
	Vector3(-0.16, 0.51, -0.76),  # inner wing L
	Vector3(0.11, 0.52, -0.78),   # inner wing R
]
var edges := [[0, 1], [1, 2], [3, 5], [5, 1], [1, 6], [6, 4]]

func setup(m) -> void:
	main = m
	for i in dirs.size():
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		s.mesh = sm
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.emission_enabled = true
		mm.emission = Color(0.9, 0.95, 1.0) if i != 2 else Color(1.0, 0.85, 0.55)
		mm.emission_energy_multiplier = 1.1
		mm.albedo_color = Color(1, 1, 1)
		s.material_override = mm
		s.position = dirs[i].normalized() * 145.0
		main.add_child(s)
		stars.append(s)
		lit.append(false)

func aimed_star(c: XRController3D) -> int:
	if done:
		return -1
	var head: Vector3 = main.user_position() + Vector3(0, 1.5, 0)
	var dir := -c.global_transform.basis.z
	for i in stars.size():
		if lit[i]:
			continue
		var to := (stars[i].global_position - head).normalized()
		if dir.angle_to(to) < deg_to_rad(3.0):
			return i
	return -1

func try_tap(c: XRController3D) -> bool:
	var i := aimed_star(c)
	if i < 0:
		return false
	lit[i] = true
	var mm: StandardMaterial3D = stars[i].material_override
	mm.emission = Color(1.0, 0.88, 0.5)
	mm.emission_energy_multiplier = 3.2
	stars[i].scale = Vector3.ONE * 1.6
	var n_lit := 0
	for l in lit:
		if l: n_lit += 1
	main.audio.play2d("chime_%d" % clampi(n_lit, 1, 7), -4.0)
	if n_lit == lit.size():
		_complete()
	return true

func _process(_delta: float) -> void:
	if done or main.controllers.is_empty():
		return
	# hover glow
	for i in stars.size():
		if lit[i]:
			continue
		var hovered := false
		for c in main.controllers:
			if aimed_star(c) == i:
				hovered = true
				break
		var mm: StandardMaterial3D = stars[i].material_override
		mm.emission_energy_multiplier = 2.6 if hovered else 1.1 + 0.25 * sin(main.t * 2.0 + float(i))
		stars[i].scale = Vector3.ONE * (1.3 if hovered else 1.0)

func _complete() -> void:
	done = true
	main.audio.play2d("hatch_chord", -5.0, 1.25)
	if not lines_drawn:
		lines_drawn = true
		for e in edges:
			var a: Vector3 = stars[e[0]].global_position
			var b: Vector3 = stars[e[1]].global_position
			var line := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.09
			cm.bottom_radius = 0.09
			cm.height = a.distance_to(b)
			line.mesh = cm
			var mm := StandardMaterial3D.new()
			mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mm.albedo_color = Color(0.7, 0.85, 1.0, 0.22)
			line.material_override = mm
			line.position = (a + b) * 0.5
			line.look_at(b, Vector3.UP)
			line.rotate_object_local(Vector3.RIGHT, PI / 2)
			main.add_child(line)
	_shooting_star()
	main.flock.request_flyby()
	main.nest.enable_glow()
	main.fireflies.celebrate()

func _shooting_star() -> void:
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.4; sm.height = 0.8
	s.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.emission_enabled = true
	mm.emission = Color(1, 1, 0.9)
	mm.emission_energy_multiplier = 8.0
	s.material_override = mm
	main.add_child(s)
	var a := Vector3(-90, 80, -110)
	var b := Vector3(70, 45, -80)
	s.position = a
	var tw := create_tween()
	tw.tween_property(s, "position", b, 1.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mm, "emission_energy_multiplier", 0.0, 1.4)
	tw.tween_callback(s.queue_free)
