class_name SwanFlock
extends Node3D
# Owns the swans, roam anchor drift, gather choreography.

var main  # SwanLakeMain (untyped: avoids cyclic class_name resolution)
var swans: Array[Swan] = []
var roam_anchor := Vector3(0, 0, -9)
var attract_active := false
var attract_point := Vector3.ZERO
var gather_on := false
var t := 0.0

func spawn(count: int) -> void:
	var scene: PackedScene = load("res://assets/swan.glb")
	for i in count:
		var s := Swan.new()
		add_child(s)
		swans.append(s)
		var model: Node3D = scene.instantiate()
		var scale_v := 1.0 if i > 0 else 1.14  # swan 0 is the prima
		model.scale = Vector3.ONE * scale_v
		s.setup(main, self, model, float(i) * 1.618)
		var a := TAU * float(i) / float(count)
		var r := randf_range(4.0, 9.0)
		s.global_position = main.LAKE_CENTER + Vector3(cos(a) * r, 0, sin(a) * r * 0.7)
	# prima roams a bit nearer the dock
	swans[0].wander_seed = 0.31

func music_energy() -> float:
	return main.music.energy

func set_gather(on: bool, point: Vector3) -> void:
	gather_on = on
	if on:
		var n := swans.size()
		var user: Vector3 = main.user_position()
		var to_user: Vector3 = (user - point)
		to_user.y = 0
		var base_ang := atan2(to_user.x, to_user.z)  # circle opens toward the user
		for i in n:
			var frac := (float(i) + 0.5) / float(n)
			var ang := base_ang + (frac - 0.5) * TAU * 0.78
			var rad := 2.6 if i > 0 else 1.5  # prima closest, center-ish
			swans[i].gather_slot = point + Vector3(sin(ang) * rad, 0, cos(ang) * rad)
			if i % 3 == 0:
				swans[i].trigger_flap()
	else:
		for s in swans:
			s.gather_slot = Vector3.INF
			s.arrived = false

func _process(delta: float) -> void:
	t += delta
	roam_anchor = main.LAKE_CENTER + Vector3(sin(t * 0.045) * 5.0, 0, cos(t * 0.032) * 3.5)
	for s in swans:
		s.update_swan(delta, main.t)
	# ambient: prima stretches on big musical swells
	if main.music.swell_flag:
		main.music.swell_flag = false
		swans[randi() % swans.size()].trigger_flap()

func add_swan_ref(s: Swan) -> void:
	swans.append(s)
