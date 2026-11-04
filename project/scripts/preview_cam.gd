class_name PreviewRig
extends Node3D
# Desktop fallback. Move the mouse: the baton follows it. Left click: downbeat (ripple, on-beat).
# Right drag: look. Wheel: dolly. ENTER: next movement.
# Keys: 1/2/3 mood · SPACE ripple burst · G gather · K firework · W weather
#       R reflections · S swan style · B baton pose · T SFX timing · M orb menu
#       C complete Cygnus (cheat) · N hatch (cheat) · H fps HUD · P screenshot
# --shot: deterministic captures across moods/features, then quit.

var main  # SwanLakeMain (untyped: cyclic)
var cam: Camera3D
var yaw := 0.0
var pitch := -0.06
var dist := 0.0
var dragging := false
var auto_t := 0.0
var shot_mode := false
var mouse_baton := true

func _ready() -> void:
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	cam.fov = 75
	add_child(cam)
	position = Vector3(0, 1.75, 0.9)
	shot_mode = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stills") or a.begins_with("--autotest") or a == "--swanlab" or a.begins_with("--clip"):
			shot_mode = true

func _pose() -> void:
	cam.position = Vector3(0, 0, dist)
	rotation = Vector3(pitch, yaw, 0)

func _process(delta: float) -> void:
	_pose()
	if mouse_baton and not shot_mode:
		var vp := get_viewport()
		var m := vp.get_mouse_position()
		var from := cam.project_ray_origin(m)
		var dir := cam.project_ray_normal(m)
		if main.conductor:
			main.conductor.desktop_tip = from + dir * 0.75
			main.set_reticle_preview(_baton_point(), true)
	else:
		main.set_reticle_preview(_gaze_point(), false)

func _baton_point() -> Vector3:
	var p: Vector3 = main.baton_water_point()
	return p if p != Vector3.INF else _gaze_point()

func _gaze_point() -> Vector3:
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	if dir.y > -0.02:
		return Vector3(0, 0, -6.5)
	return from + dir * (from.y / -dir.y)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			dragging = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			main.press_primary(main.baton_aim_pose(), true)
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
			KEY_SPACE: main.do_ripple(_baton_point(), 0.85)
			KEY_ENTER: main.program.next_movement()
			KEY_G:
				main.gather_point = _baton_point()
				main.set_gather(not main.gather_on)
			KEY_K: main.fireworks.try_manual(_baton_point())
			KEY_W: main.weather.cycle()
			KEY_R: main.reflections.cycle()
			KEY_C: main.constellation._complete()
			KEY_N:
				main.nest.enable_glow()
				main.nest.taps = 2
				main.nest.glow_egg.visible = true
				main.nest._hatch()
			KEY_S: main.flock.cycle_style()
			KEY_B: main.conductor.cycle_pose()
			KEY_T: main.music.cycle_timing()
			KEY_M: main.menu.toggle()
			KEY_X: main.megaflock.cycle()
			KEY_H: main.perf.set_hud(not main.perf.hud_on)
