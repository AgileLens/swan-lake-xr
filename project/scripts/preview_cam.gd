class_name PreviewRig
extends Node3D
# Desktop look-dev rig. Drag = look, wheel = dolly.
# Keys: 1/2/3 mood · SPACE ripple burst · G gather · F finale · K firework · W weather
#       R reflections · C complete Cygnus (cheat) · N hatch (cheat) · H fps HUD · P screenshot
# --shot: deterministic captures across moods/features, then quit.

var main  # SwanLakeMain (untyped: cyclic)
var cam: Camera3D
var yaw := 0.0
var pitch := -0.06
var dist := 0.0
var dragging := false
var auto_t := 0.0
var shot_mode := false

func _ready() -> void:
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.fov = 75
	add_child(cam)
	position = Vector3(0, 1.75, 0.9)
	shot_mode = "--shot" in OS.get_cmdline_user_args()
	if shot_mode:
		_run_shots()

func _pose() -> void:
	cam.position = Vector3(0, 0, dist)
	rotation = Vector3(pitch, yaw, 0)

func _process(delta: float) -> void:
	if not dragging and not shot_mode:
		auto_t += delta
		yaw = sin(auto_t * 0.05) * 0.35
	_pose()
	main.set_reticle_preview(_gaze_point(), true)

func _gaze_point() -> Vector3:
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	if dir.y > -0.02:
		return Vector3(0, 0, -6.5)
	return from + dir * (from.y / -dir.y)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			dragging = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(dist - 0.4, -2.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(dist + 0.4, 8.0)
	elif ev is InputEventMouseMotion and dragging:
		yaw -= ev.relative.x * 0.004
		pitch = clampf(pitch - ev.relative.y * 0.004, -1.2, 0.6)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_1: main.mood.apply("night", false)
			KEY_2: main.mood.apply("dusk", false)
			KEY_3: main.mood.apply("dawn", false)
			KEY_SPACE: main.do_ripple(_gaze_point(), 0.85)
			KEY_G:
				main.gather_point = _gaze_point()
				main.set_gather(not main.gather_on)
			KEY_F: main.trigger_finale()
			KEY_K: main.fireworks.try_manual(_gaze_point())
			KEY_W: main.weather.cycle()
			KEY_R: main.reflections.cycle()
			KEY_C: main.constellation._complete()
			KEY_N:
				main.nest.enable_glow()
				main.nest.taps = 2
				main.nest.glow_egg.visible = true
				main.nest._hatch()
			KEY_S: main.flock.cycle_style()
			KEY_H: main.perf.set_hud(not main.perf.hud_on)
			KEY_P: _save_shot("manual_%d" % (Time.get_ticks_msec() % 10000))

func _save_shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://../out/shots")
	img.save_png("res://../out/shots/%s.png" % name)
	print("SHOT_SAVED ", name)

func _shot_pose(p: Vector3, y: float, pt: float) -> void:
	position = p
	yaw = y
	pitch = pt
	_pose()

func _run_shots() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): print("SHOT_WATCHDOG_QUIT"); get_tree().quit())
	await get_tree().create_timer(1.0).timeout
	main.title.skip_intro()
	await get_tree().create_timer(2.0).timeout
	_shot_pose(Vector3(0, 1.75, 0.9), 0.0, -0.06)
	await _settle(0.5)
	_save_shot("night_dock")
	main.gather_point = Vector3(0, 0, -6.5)
	main.set_gather(true)
	await _settle(8.0)
	_save_shot("night_gather")
	main.set_gather(false)
	main.mood.apply("dusk", false)
	await _settle(3.0)
	main.fireworks.launch(Vector3(-5, 0, -14))
	main.fireworks.launch(Vector3(4, 0, -17))
	await _settle(1.9)
	_save_shot("dusk_fireworks")
	main.mood.apply("dawn", false)
	await _settle(3.0)
	_shot_pose(Vector3(2.5, 0.5, -3.0), 0.5, 0.02)
	await _settle(0.5)
	_save_shot("dawn_low")
	main.mood.apply("night", false)
	main.weather.set_weather("snow")
	await _settle(4.0)
	_shot_pose(Vector3(0, 1.75, 0.9), 0.0, -0.02)
	await _settle(0.5)
	_save_shot("night_snow")
	main.weather.set_weather("clear")
	main.reflections.apply(2)
	main.set_gather(true)
	await _settle(3.0)
	_shot_pose(Vector3(0, 1.1, 0.5), 0.0, -0.04)
	await _settle(0.5)
	_save_shot("night_planar")
	main.reflections.apply(0)
	main.set_gather(false)
	main.mood.apply("night", false)
	await _settle(2.0)
	for i in 4:
		while main.flock.style_idx != i:
			main.flock.cycle_style()
		await _settle(1.0)
		var sp: Vector3 = main.flock.swans[2].global_position
		position = sp + Vector3(2.4, 0.95, 3.2)
		yaw = atan2(position.x - sp.x, position.z - sp.z)
		pitch = -0.16
		_pose()
		await _settle(0.4)
		_save_shot("swanstyle_%d" % i)
	print("SHOTS_DONE")
	get_tree().quit()

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
	await get_tree().process_frame
	await get_tree().process_frame
