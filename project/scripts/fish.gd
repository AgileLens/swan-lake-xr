class_name FishSchool
extends Node
# Silver fish arc out of the water: ambient jumps, more in rain, and a finale ballet.

var main  # SwanLakeMain
var pool: Array[Node3D] = []
var jumps: Array[Dictionary] = []
var ambient_timer := 14.0
var ballet_queue: Array[float] = []
var ballet_clock := 0.0

func setup(m) -> void:
	main = m
	var scene: PackedScene = load("res://assets/fish.glb")
	for i in 6:
		var f: Node3D = scene.instantiate()
		f.visible = false
		main.add_child(f)
		pool.append(f)

func jump(from: Vector3, heading: Vector3, peak := 1.0, dur := 0.95) -> void:
	for f in pool:
		if not f.visible:
			f.visible = true
			var to := from + heading.normalized() * randf_range(1.2, 2.2)
			jumps.append({"n": f, "a": from, "b": to, "t": 0.0, "dur": dur, "peak": peak})
			main.ripples.add(from, 0.09)
			main.music.schedule_sfx(func(): main.audio.plop(from, 0.7))
			return

func ballet() -> void:
	# five staggered crossing jumps through the gather beam area
	ballet_queue = [0.0, 0.5, 1.0, 1.5, 2.0]
	ballet_clock = 0.0

func _process(delta: float) -> void:
	ambient_timer -= delta
	var period := 22.0
	if main.weather and main.weather.current == "rain":
		period = 7.0
	if ambient_timer <= 0.0:
		ambient_timer = randf_range(period * 0.7, period * 1.5)
		var near: Vector3 = main.flock.swans[randi() % main.flock.swans.size()].global_position if main.flock and not main.flock.swans.is_empty() else Vector3(0, 0, -8)
		var p := near + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		jump(Vector3(p.x, 0, p.z), Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), randf_range(0.7, 1.3))
	if not ballet_queue.is_empty():
		ballet_clock += delta
		while not ballet_queue.is_empty() and ballet_clock >= ballet_queue[0]:
			ballet_queue.pop_front()
			var gx: float = main.gather_point.x
			var gz: float = main.gather_point.z
			var side := 1.0 if randf() > 0.5 else -1.0
			jump(Vector3(gx - side * 1.6, 0, gz + randf_range(-0.8, 0.8)),
				Vector3(side, 0, randf_range(-0.3, 0.3)), 1.45, 1.1)
	var done: Array[Dictionary] = []
	for j in jumps:
		j.t += delta
		var u: float = j.t / j.dur
		if u >= 1.0:
			var n: Node3D = j.n
			n.visible = false
			main.ripples.add(j.b, 0.08)
			main.music.schedule_sfx(func(): main.audio.play3d("splash", j.b, -16.0))
			done.append(j)
			continue
		var pos: Vector3 = j.a.lerp(j.b, u)
		pos.y = sin(u * PI) * j.peak
		var vel: Vector3 = (j.b - j.a) / j.dur
		vel.y = cos(u * PI) * PI * j.peak / j.dur
		var n2: Node3D = j.n
		n2.global_position = pos
		if vel.length() > 0.01:
			n2.look_at(pos + vel.normalized(), Vector3.UP)
	for j in done:
		jumps.erase(j)
