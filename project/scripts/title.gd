class_name TitleCards
extends Node
# Agile Lens intro card (fade from black, wordmark + orbit motif) and finale outro card.

var main  # SwanLakeMain
var fade_quad: MeshInstance3D
var fade_mat: StandardMaterial3D
var intro_root: Node3D
var orbit_dot: MeshInstance3D
var orbit_ring: MeshInstance3D
var _orbit_t := 0.0
var intro_done := false

func setup(m) -> void:
	main = m
	# camera-attached fade quad (XR-safe "screen fade")
	fade_quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(4, 4)
	fade_quad.mesh = qm
	fade_mat = StandardMaterial3D.new()
	fade_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fade_mat.albedo_color = Color(0, 0, 0, 1)
	fade_mat.no_depth_test = true
	fade_mat.render_priority = 100
	fade_quad.material_override = fade_mat
	fade_quad.position = Vector3(0, 0, -0.7)
	_camera().add_child(fade_quad)
	_intro()

func _camera() -> Node3D:
	if main.xr_active and main.origin:
		for c in main.origin.get_children():
			if c is XRCamera3D:
				return c
	var pv: Node = main.get_node_or_null("PreviewRig")
	if pv:
		var cam: Node = pv.get_node_or_null("Camera3D")
		if cam:
			return cam
	return main

func _label(txt: String, size: int, pos: Vector3, parent: Node3D) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.font_size = size
	l.outline_size = 0
	l.modulate = Color(1, 1, 1, 0)
	l.pixel_size = 0.004
	l.position = pos
	parent.add_child(l)
	return l

func _intro() -> void:
	intro_root = Node3D.new()
	intro_root.position = Vector3(0, 2.1, -5.5)
	main.add_child(intro_root)
	var a := _label("A G I L E   L E N S", 44, Vector3(0, 0.55, 0), intro_root)
	var b := _label("p r e s e n t s", 20, Vector3(0, 0.28, 0), intro_root)
	var c := _label("S W A N   L A K E", 84, Vector3(0, -0.18, 0), intro_root)
	var d := _label("a  P I C O   S w a n  e x p e r i e n c e", 18, Vector3(0, -0.52, 0), intro_root)
	# orbit motif: thin ring + orbiting dot above the wordmark
	orbit_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.145
	tm.outer_radius = 0.155
	orbit_ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1, 1, 1, 0.0)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orbit_ring.material_override = rm
	orbit_ring.rotation_degrees = Vector3(78, 0, 12)
	orbit_ring.position = Vector3(0, 1.0, 0)
	intro_root.add_child(orbit_ring)
	orbit_dot = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.02; sm.height = 0.04
	orbit_dot.mesh = sm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.emission_enabled = true
	dm.emission = Color(1, 1, 1)
	dm.albedo_color = Color(1, 1, 1, 0)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orbit_dot.material_override = dm
	intro_root.add_child(orbit_dot)
	# sequence: fade scene in under the black, reveal lines, hold, dissolve
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(a, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property(rm, "albedo_color:a", 0.85, 1.2)
	tw.parallel().tween_property(dm, "albedo_color:a", 1.0, 1.2)
	tw.tween_property(b, "modulate:a", 0.85, 0.8)
	tw.tween_property(fade_mat, "albedo_color:a", 0.0, 2.4)
	tw.parallel().tween_property(c, "modulate:a", 1.0, 1.6)
	tw.parallel().tween_property(d, "modulate:a", 0.7, 1.6)
	tw.tween_interval(2.8)
	tw.tween_callback(_dissolve_intro)

func _dissolve_intro() -> void:
	if intro_done:
		return
	intro_done = true
	main.fireflies.celebrate()
	var tw := create_tween()
	tw.tween_property(intro_root, "position", intro_root.position + Vector3(0, 0.8, 0), 1.8)
	for ch in intro_root.get_children():
		if ch is Label3D:
			tw.parallel().tween_property(ch, "modulate:a", 0.0, 1.6)
		elif ch is MeshInstance3D:
			tw.parallel().tween_property(ch.material_override, "albedo_color:a", 0.0, 1.4)
	tw.tween_callback(intro_root.queue_free)

func skip_intro() -> void:
	if not intro_done:
		fade_mat.albedo_color.a = 0.0
		_dissolve_intro()

func outro() -> void:
	var root := Node3D.new()
	root.position = Vector3(0, 2.3, -6.0)
	main.add_child(root)
	var a := _label("S W A N   L A K E", 64, Vector3(0, 0.15, 0), root)
	var b := _label("A G I L E   L E N S   ×   P I C O", 26, Vector3(0, -0.22, 0), root)
	var tw := create_tween()
	tw.tween_property(a, "modulate:a", 1.0, 1.4)
	tw.parallel().tween_property(b, "modulate:a", 0.85, 1.4)
	tw.tween_interval(6.0)
	tw.tween_property(a, "modulate:a", 0.0, 2.0)
	tw.parallel().tween_property(b, "modulate:a", 0.0, 2.0)
	tw.tween_callback(root.queue_free)

func _process(delta: float) -> void:
	if orbit_dot and is_instance_valid(orbit_dot) and orbit_ring and is_instance_valid(orbit_ring):
		_orbit_t += delta * 1.6
		var r := 0.15
		orbit_dot.position = orbit_ring.position + Vector3(cos(_orbit_t) * r, sin(_orbit_t) * r * 0.28, sin(_orbit_t) * r * 0.5)
