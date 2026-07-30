class_name SwanFlock
extends Node3D
# Owns the swans + cygnet, roam-anchor drift, gather choreography, flyby scheduling.

const STYLES := ["res://assets/swan_style0.glb", "res://assets/swan_style1.glb",
	"res://assets/swan_style2.glb", "res://assets/swan_style3.glb"]
const STYLE_NAMES := ["origami", "lowpoly", "organic", "detailed"]

var main  # SwanLakeMain (untyped: avoids cyclic class_name resolution)
var style_idx := 2
var swans: Array[Swan] = []
var roam_anchor := Vector3(0, 0, -9)
var attract_active := false
var attract_point := Vector3.ZERO
var gather_on := false
var t := 0.0
var flyby_timer := 250.0

func spawn(count: int) -> void:
	var scene: PackedScene = load(STYLES[style_idx])
	for i in count:
		var s := Swan.new()
		var model: Node3D = scene.instantiate()
		add_child(s)
		s.setup(main, self, model, float(i) * 1.618)
		var a := TAU * float(i) / count
		s.global_position = main.LAKE_CENTER + Vector3(cos(a) * randf_range(3, 7), 0, sin(a) * randf_range(3, 7))
		if i == 0:
			s.scale = Vector3.ONE * 1.12  # prima
		swans.append(s)

func spawn_cygnet(at: Vector3) -> void:
	var scene: PackedScene = load(STYLES[style_idx])
	var s := Swan.new()
	var model: Node3D = scene.instantiate()
	_tint_gray(model)
	add_child(s)
	s.setup(main, self, model, 9.9)
	s.is_cygnet = true
	s.scale = Vector3.ONE * 0.42
	s.global_position = at
	s.follow_target = swans[0]
	swans.append(s)

func _tint_gray(node: Node) -> void:
	for ch in node.get_children():
		_tint_gray(ch)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			return
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var m2: StandardMaterial3D = m.duplicate()
				m2.albedo_color = m2.albedo_color * Color(0.80, 0.82, 0.85, 1.0)
				mi.set_surface_override_material(i, m2)

func set_gather(on: bool, point: Vector3) -> void:
	gather_on = on
	if on:
		var n := 0
		for s in swans:
			if not s.flying and not s.is_cygnet:
				n += 1
		var user: Vector3 = main.user_position()
		var to_user: Vector3 = (user - point)
		to_user.y = 0
		var base_ang: float = atan2(to_user.x, to_user.z)
		var k := 0
		for s in swans:
			if s.flying or s.is_cygnet:
				continue
			var frac := float(k) / maxf(n - 1, 1)
			var ang := base_ang + (frac - 0.5) * TAU * 0.78
			var rad := 2.2 if k > 0 else 1.2
			s.gather_slot = point + Vector3(sin(ang) * rad, 0, cos(ang) * rad)
			s.trigger_flap()
			k += 1
	else:
		for s in swans:
			s.gather_slot = Vector3.INF
			s.arrived = false

func style_name() -> String:
	return STYLE_NAMES[style_idx]

func cycle_style() -> void:
	style_idx = (style_idx + 1) % STYLES.size()
	var scene: PackedScene = load(STYLES[style_idx])
	for s in swans:
		var model: Node3D = scene.instantiate()
		if s.is_cygnet:
			_tint_gray(model)
		s.swap_model(model)

func request_flyby() -> void:
	for s in swans:
		if not s.flying and not s.is_cygnet and s.gather_slot == Vector3.INF:
			s.start_flyby()
			return

func music_energy() -> float:
	return main.music.energy if main.music else 0.0

func _process(delta: float) -> void:
	t += delta
	roam_anchor = main.LAKE_CENTER + Vector3(sin(t * 0.05) * 4.0, 0, cos(t * 0.037) * 3.0)
	if not gather_on:
		flyby_timer -= delta
		if flyby_timer <= 0.0:
			flyby_timer = randf_range(240.0, 330.0)
			request_flyby()
	for s in swans:
		s.update_swan(delta, t)
