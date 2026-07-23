class_name PreviewRig
extends Node3D
# Desktop fallback: orbit/look camera for look-dev + deterministic screenshot mode.
# Keys: drag = look, wheel = dolly, 1/2/3 mood, SPACE ripple, G gather, F finale, P screenshot.
# --shot: waits, captures 3 angles to out/shots/, quits.

var main  # SwanLakeMain (untyped: cyclic)
var cam: Camera3D
var yaw := 0.0
var pitch := -0.06
var dist := 0.0  # 0 = first person on dock
var dragging := false
var auto_t := 0.0
var shot_mode := false
var shot_step := 0

const EYE := Vector3(0, 1.75, 0.9)

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 70
	add_child(cam)
	cam.current = true
	shot_mode = "--shot" in OS.get_cmdline_user_args()
	if shot_mode:
		_run_shots()

func _process(delta: float) -> void:
	if not dragging and not shot_mode:
		auto_t += delta
		yaw = sin(auto_t * 0.05) * 0.35
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0))
	cam.global_transform = Transform3D(basis, EYE + basis.z * dist)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(dist - 0.5, 0.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(dist + 0.5, 12.0)
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch - event.relative.y * 0.004, -1.2, 0.5)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: main.mood.apply("night", false)
			KEY_2: main.mood.apply("dusk", false)
			KEY_3: main.mood.apply("dawn", false)
			KEY_SPACE: main.do_ripple(_gaze_point(), 0.85)
			KEY_G: main.set_gather(not main.gather_on)
			KEY_F: main.music.play_finale()
			KEY_P: _save_png("out/shots/manual_%d.png" % Time.get_ticks_msec())

func _gaze_point() -> Vector3:
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	if dir.y > -0.02:
		return Vector3(0, 0, -6.5)
	return from + dir * (from.y / -dir.y)

func _save_png(rel_path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path("res://../" + rel_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	img.save_png(abs_path)
	print("SHOT_SAVED ", abs_path)

func _run_shots() -> void:
	# deterministic look-dev captures across all three moods + a gather beat
	get_tree().create_timer(60.0).timeout.connect(func(): print("SHOT_WATCHDOG_QUIT"); get_tree().quit())
	await get_tree().create_timer(2.5).timeout
	var poses := [
		# [name, eye, yaw, pitch, pre-action]
		["night_dock", EYE, 0.0, -0.05, ""],
		["night_gather", EYE, 0.0, -0.18, "gather"],
		["dusk_dock", EYE, 0.25, -0.04, "dusk"],
		["dawn_low", Vector3(2.5, 0.5, -3.0), 0.5, 0.02, "dawn"],
	]
	for p in poses:
		match p[4]:
			"gather":
				main.set_gather(true)
				await get_tree().create_timer(6.0).timeout
			"dusk":
				main.set_gather(false)
				main.mood.apply("dusk", true)
				await get_tree().create_timer(1.5).timeout
			"dawn":
				main.mood.apply("dawn", true)
				await get_tree().create_timer(1.5).timeout
			_:
				await get_tree().create_timer(0.5).timeout
		var basis := Basis.from_euler(Vector3(p[3], p[2], 0))
		cam.global_transform = Transform3D(basis, p[1])
		await get_tree().process_frame
		await get_tree().process_frame
		_save_png("out/shots/%s.png" % p[0])
	print("SHOTS_DONE")
	get_tree().quit()
