class_name SwanNest
extends Node
# Nest with three eggs near the reeds. After Cygnus completes, one egg glows;
# three baton taps hatch a cygnet that follows the prima swan.

var main  # SwanLakeMain
var root: Node3D
var glow_egg: MeshInstance3D
var egg_mat: StandardMaterial3D
var glowing := false
var taps := 0
var hatched := false
const POS := Vector3(2.7, 0.02, -3.4)

func setup(m) -> void:
	main = m
	root = Node3D.new()
	root.position = POS
	main.add_child(root)
	var twigs := StandardMaterial3D.new()
	twigs.albedo_color = Color(0.10, 0.07, 0.05)
	twigs.roughness = 1.0
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.30
	ring.mesh = tm
	ring.scale = Vector3(1, 0.45, 1)
	ring.material_override = twigs
	root.add_child(ring)
	for i in 3:
		var egg := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.062
		sm.height = 0.15
		egg.mesh = sm
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.94, 0.92, 0.86)
		em.roughness = 0.5
		egg.material_override = em
		var a := TAU * i / 3.0
		egg.position = Vector3(cos(a) * 0.09, 0.06, sin(a) * 0.09)
		egg.rotation_degrees = Vector3(randf_range(-14, 14), 0, randf_range(-14, 14))
		root.add_child(egg)
		if i == 0:
			glow_egg = egg
			egg_mat = em

func enable_glow() -> void:
	if hatched:
		return
	glowing = true
	egg_mat.emission_enabled = true
	egg_mat.emission = Color(0.7, 0.9, 1.0)

func aimed(c: XRController3D) -> bool:
	if not glowing or hatched:
		return false
	var from := c.global_position
	var dir := -c.global_transform.basis.z
	var to := glow_egg.global_position
	return dir.angle_to((to - from).normalized()) < deg_to_rad(4.0) and from.distance_to(to) < 8.0

func try_tap(c: XRController3D) -> bool:
	if not aimed(c):
		return false
	taps += 1
	main.audio.plop(glow_egg.global_position, 0.4)
	glow_egg.scale = Vector3.ONE * (1.0 + 0.18 * taps)
	egg_mat.emission_energy_multiplier = 1.0 + taps * 1.2
	if taps >= 3:
		_hatch()
	return true

func _hatch() -> void:
	hatched = true
	glowing = false
	glow_egg.visible = false
	main.audio.play2d("hatch_chord", -3.0)
	var shell := GPUParticles3D.new()
	shell.one_shot = true
	shell.amount = 40
	shell.lifetime = 1.4
	shell.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.spread = 180.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.3
	shell.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.94, 0.92, 0.86)
	quad.material = mm
	shell.draw_pass_1 = quad
	shell.position = root.position + Vector3(0, 0.1, 0)
	main.add_child(shell)
	shell.restart()
	main.fireflies.celebrate()
	main.flock.spawn_cygnet(root.position + Vector3(-0.5, 0, -0.5))
