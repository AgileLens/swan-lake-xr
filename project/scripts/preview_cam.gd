class_name PreviewRig
extends Node3D
# Desktop look-dev rig. Drag = look, wheel = dolly.
# Keys: 1/2/3 mood · SPACE ripple burst · G gather · F finale · K firework · W weather
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
			KEY_B: main.conductor.cycle_pose()
			KEY_T: main.music.cycle_timing()
			KEY_M: main.menu.toggle()
			KEY_X: main.megaflock.cycle()
			KEY_H: main.perf.set_hud(not main.perf.hud_on)
			KEY_P: _save_shot("manual_%d" % (Time.get_ticks_msec() % 10000))

func _save_shot(name: String) -> void:
	# MUST await frame_post_draw: get_texture() returns the last *drawn* frame, and
	# `await process_frame` fires BEFORE drawing — so capturing after it hands back
	# the previous frame. That silently produced duplicate captures (night_gather,
	# beam_closeup and beam_side were byte-identical files), which means a shot can
	# "verify" a change that was never rendered. Caught by md5-ing the shot set.
	await RenderingServer.frame_post_draw
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
	# Wipe previous captures first. A run that dies early used to leave the old
	# PNGs in place, and those stale files read as fresh results — that is how a
	# 90s timeout got mistaken for "the corps chorus renders identically".
	var d := DirAccess.open("res://../out/shots")
	if d:
		for f in d.get_files():
			if f.ends_with(".png"):
				d.remove(f)
	# generous: the scene got much heavier (cloud/aurora sky + up to 2000 corps)
	get_tree().create_timer(300.0).timeout.connect(func(): print("SHOT_WATCHDOG_QUIT"); get_tree().quit())
	await get_tree().create_timer(1.0).timeout
	# after the await: the rig is built inside main._ready(), before perf exists
	main.perf.enabled = false  # deterministic captures — low desktop fps would shed features
	main.title.skip_intro()
	await get_tree().create_timer(2.0).timeout
	_shot_pose(Vector3(0, 1.75, 0.9), 0.0, -0.06)
	await _settle(0.5)
	await _save_shot("night_dock")
	main.gather_point = Vector3(0, 0, -6.5)
	main.set_gather(true)
	await _settle(8.0)
	await _save_shot("night_gather")
	# beam close-up: Alex reported it reading as inverted normals in the headset
	_shot_pose(Vector3(0, 1.6, -2.2), 0.0, 0.06)
	await _settle(0.5)
	await _save_shot("beam_closeup")
	var bp := Vector3(3.2, 1.5, -3.5)
	_shot_pose(bp, atan2(bp.x - main.gather_point.x, bp.z - main.gather_point.z), -0.10)
	await _settle(0.4)
	await _save_shot("beam_side")
	_shot_pose(Vector3(0, 1.75, 0.9), 0.0, -0.06)
	main.set_gather(false)
	main.mood.apply("dusk", false)
	await _settle(3.0)
	main.fireworks.launch(Vector3(-5, 0, -14))
	main.fireworks.launch(Vector3(4, 0, -17))
	await _settle(1.9)
	await _save_shot("dusk_fireworks")
	main.mood.apply("dawn", false)
	await _settle(3.0)
	_shot_pose(Vector3(2.5, 0.5, -3.0), 0.5, 0.02)
	await _settle(0.5)
	await _save_shot("dawn_low")
	main.mood.apply("night", false)
	main.weather.set_weather("snow")
	await _settle(4.0)
	_shot_pose(Vector3(0, 1.75, 0.9), 0.0, -0.02)
	await _settle(0.5)
	await _save_shot("night_snow")
	main.weather.set_weather("clear")
	main.reflections.apply(2)
	main.set_gather(true)
	await _settle(3.0)
	_shot_pose(Vector3(0, 1.1, 0.5), 0.0, -0.04)
	await _settle(0.5)
	await _save_shot("night_planar")
	# stereo planar: dump both eye reflection buffers so the disparity is checkable
	main.reflections.apply(3)
	await _settle(1.2)
	await _save_shot("night_planar_stereo")
	for eye in 2:
		var img: Image = main.reflections.viewports[eye].get_texture().get_image()
		img.save_png("res://../out/shots/refl_eye_%d.png" % eye)
	print("STEREO_EYES n=", main.reflections.viewports.size(),
		" L=", main.reflections.refl_cams[0].global_position,
		" R=", main.reflections.refl_cams[1].global_position)
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
		await _save_shot("swanstyle_%d" % i)
	# settings orbs: the arc layout has to stay readable as options accumulate
	_shot_pose(Vector3(0, 1.35, 0.6), 0.0, -0.02)
	main.menu.toggle()
	await _settle(0.6)
	await _save_shot("orb_menu")
	print("MENU_ORBS ", main.menu.orbs.size(),
		" baton=", main.conductor.pose_label(),
		" timing=", main.music.timing_mode_name(),
		" grid=", snappedf(main.music.grid_seconds(), 0.001))
	main.menu.toggle()
	main.megaflock.set_level(3)
	main.fireworks.launch(Vector3(-5, 0, -16))
	main.fireworks.launch(Vector3(5, 0, -19))
	await _settle(1.9)
	position = Vector3(0, 2.4, 0.8)
	yaw = 0.0
	pitch = -0.10
	_pose()
	await _settle(0.4)
	await _save_shot("finale_corps_2000")
	# audience vs chorus: same crowd, two behaviors. Captured explicitly so the
	# wing lift and sway are verified as visible, not just assumed from uniforms.
	position = Vector3(0, 1.9, -8.0)
	yaw = PI
	pitch = -0.02
	_pose()
	var cm: ShaderMaterial = main.megaflock._shader_mat
	# freeze the driver: its _process re-derives chorus from music energy every
	# frame, so uniforms set here are overwritten before the capture lands
	main.megaflock.set_process(false)
	cm.set_shader_parameter("chorus", 0.0)
	await _settle(0.5)
	await _save_shot("corps_audience")
	cm.set_shader_parameter("chorus", 1.0)
	cm.set_shader_parameter("bar_phase", 0.5)   # peak of the wing lift
	cm.set_shader_parameter("beat_phase", 0.25)
	await _settle(0.5)
	await _save_shot("corps_chorus")
	main.megaflock.set_process(true)
	print("CORPS beat=", snappedf(main.music.beat_phase(), 0.01),
		" bar=", snappedf(main.music.bar_phase(), 0.01),
		" beat_sec=", snappedf(main.music.beat_seconds(), 0.001))
	main.megaflock.set_level(0)
	print("SHOTS_DONE")
	get_tree().quit()

func _settle(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
	# frame_post_draw, not process_frame — see _save_shot for why
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
