extends Node
# --stills[=name]: hero stills at true 3840x2160 with the Mobile renderer, the real scene and no
# UI: a SubViewport sharing the game's world. Each shot stages a real movement through the same
# calls the program uses, then holds the camera where a wearer's eyes would be unless the name
# says it's a closer look. Output: ../stills/<name>.png. A full run wipes the folder first.
const W := 3840
const H := 2160
var main
var vp: SubViewport
var cam: Camera3D
var out_dir := ""
var want := ""
var scale_down := 1

func _perf_probe() -> void:
	# Engine counters per movement, on the desktop window with default quality. It says how the
	# scene's load compares with v4's. It says nothing about frame rate on a headset GPU.
	main.perf.enabled = false
	main.title.skip_intro()
	main.title.cards_enabled = false
	main.music.virtual_clock = true
	var rig = main.get_node("PreviewRig")
	rig.position = Vector3(0, 1.72, 0.6)
	await get_tree().create_timer(1.0).timeout
	var shots := [["dawn", 80.0, "sunrise", "mist", 1], ["regatta", 30.0, "morning", "breeze", 1], ["storm", 60.0, "storm", "rain", 1],
		["clearing", 60.0, "clearing", "clear", 1], ["cygne", 60.0, "golden", "clear", 1], ["moonlight", 60.0, "night", "clear", 2],
		["scene", 60.0, "night", "snow", 2], ["finale", 190.0, "gala", "clear", 3]]
	for p in shots:
		_stage(p[0], p[1], p[2], p[3])
		main.megaflock.request_level(p[4])
		await _settle(4.0)
		main.conductor.desktop_tip = main.head_transform().origin + Vector3(0.05, -0.1, -1.0)
		var sum := 0.0
		for i in 60:
			await get_tree().process_frame
			sum += get_process_delta_time()
		print("[perf] %s draws=%d prims=%d objects=%d frame_ms=%.1f vram=%.0fMB" % [p[0],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			sum / 60.0 * 1000.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("PERF_DONE")
	get_tree().quit()

func setup(m) -> void:
	main = m
	if "--perf" in OS.get_cmdline_user_args():
		_perf_probe()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stills="):
			want = a.substr(9)
		if a == "--draft":
			scale_down = 3
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://../stills")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if want == "":
		for f in DirAccess.get_files_at(out_dir):
			DirAccess.remove_absolute(out_dir.path_join(f))
	vp = SubViewport.new()
	vp.size = Vector2i(W / scale_down, H / scale_down)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.world_3d = main.get_viewport().find_world_3d()
	vp.mesh_lod_threshold = 0.5
	add_child(vp)
	cam = Camera3D.new()
	cam.near = 0.02
	cam.far = 1000.0
	vp.add_child(cam)
	cam.make_current()
	main.perf.enabled = false
	main.title.skip_intro()
	# No text or UI in hero stills.
	main.stand.root.visible = false
	main.title.cards_enabled = false
	main.music.virtual_clock = true
	_run()

func _ok(n: String) -> bool:
	return want == "" or want == n or n.begins_with(want)

func _aim(pos: Vector3, target: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	main.reflections.override_eye = cam.global_transform

func _save(n: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join(n + ".png"))
	print("[still] ", n, " ", img.get_width(), "x", img.get_height(), " draws=",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=",
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

func _stage(id: String, at: float, mood: String, weather := "clear") -> void:
	# Enter a movement at a given point in its music, via the real program path.
	var prog = main.program
	prog._begin(ProgramData.index_of(id))
	prog.state = ConductorsProgram.State.PLAY
	main.music.play_clip(prog.movement["clip"], 0.0, at)
	# Cues up to this point fire, as they would have by now.
	prog._cue_i = 0
	prog._run_cues(at)
	main.mood.apply(mood, true)
	main.weather.set_weather(weather)

func _settle(sec: float, baton := Vector3.INF) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		main.flock.snap = t < sec * 0.5
		if baton != Vector3.INF:
			main.conductor.desktop_tip = main.head_transform().origin + baton
	main.flock.snap = false

func _hand(offset: Vector3) -> void:
	# The conductor's baton, in view where it would be: low, right of center, aimed out.
	main.conductor.desktop_tip = main.head_transform().origin + offset

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var eye := Vector3(0, 1.72, 0.6)
	# Reflections, shadows and fireflies at their defaults: what the headset starts with.
	var rig = main.get_node("PreviewRig")
	rig.position = eye
	if _ok("01_dawn"):
		_stage("dawn", 70.0, "sunrise", "mist")
		main.flock.put_to_sleep()
		for i in 4:
			main.flock.wake_next()
		await _settle(5.0)
		_hand(Vector3(0.10, 0.22, -1.02))
		_aim(eye, Vector3(-1.0, 1.1, -8.0), 72.0)
		await _settle(0.8)
		await _save("01_dawn")
	if _ok("02_regatta"):
		_stage("regatta", 40.0, "morning", "breeze")
		main.flock.lead_point = Vector3(-3.5, 0, -5.5)
		await _settle(5.0)
		_hand(Vector3(0.02, -0.08, -1.04))
		_aim(eye + Vector3(0.1, -0.05, 0), Vector3(-1.5, 0.75, -7.0), 72.0)
		await _settle(0.5)
		await _save("02_regatta")
	if _ok("03_storm"):
		_stage("storm", 60.0, "storm", "rain")
		await _settle(5.0)
		main.storm.strike(Vector3(5.0, 0, -22.0), true)
		_hand(Vector3(0.04, 0.14, -1.04))
		_aim(eye, Vector3(1.0, 1.3, -8.0), 74.0)
		await _settle(0.05)
		await _save("03_storm")
	if _ok("04_rainbow"):
		_stage("clearing", 70.0, "clearing", "clear")
		var b := PackedByteArray(); b.resize(14); b.fill(1)
		main.rainbow.set_target(1.0)
		main.rainbow.set_bins(b, 1.0)
		main.rainbow.alpha = 1.0
		await _settle(5.0)
		_hand(Vector3(0.00, 0.24, -1.00))
		_aim(eye, Vector3(0.3, 2.3, -8.0), 78.0)
		main.rainbow.alpha = 1.0
		await _settle(0.5)
		await _save("04_rainbow")
	if _ok("05_golden_swan"):
		_stage("cygne", 45.0, "golden", "clear")
		main.flock.lead_point = Vector3(-0.2, 0, -3.3)
		await _settle(5.0)
		_hand(Vector3(0.10, -0.20, -1.03))
		_aim(eye + Vector3(0, -0.1, 0), Vector3(-0.05, 0.42, -3.3), 52.0)
		await _settle(0.5)
		await _save("05_golden_swan")
	if _ok("06_heart"):
		_stage("cygne", 120.0, "dusk", "clear")
		main.flock.set_formation("pair")
		main.flock.lead_point = Vector3(0.0, 0, -3.9)
		await _settle(6.0)
		_hand(Vector3(0.20, -0.30, -1.00))
		_aim(eye + Vector3(0, -0.25, 0), Vector3(0, 0.46, -4.0), 44.0)
		await _settle(0.5)
		await _save("06_heart")
	if _ok("07_moonrise"):
		_stage("moonlight", 60.0, "night", "clear")
		await _settle(5.0)
		for i in 4:
			main.constellation.light_next()
		main.conductor._speed_avg = 2.0
		_hand(Vector3(0.02, 0.34, -0.98))
		_aim(eye, Vector3(-0.4, 3.0, -8.0), 86.0)
		await _settle(0.5)
		await _save("07_moonrise")
	if _ok("08_scene"):
		_stage("scene", 60.0, "night", "snow")
		main.gather_point = Vector3(0, 0, -5.4)
		main.set_gather(true)
		main.beam_alpha = 0.16
		await _settle(7.0)
		_hand(Vector3(0.03, -0.10, -1.05))
		_aim(eye, Vector3(0, 1.0, -6.0), 68.0)
		await _settle(0.5)
		await _save("08_scene")
	if _ok("09_finale"):
		_stage("finale", 190.0, "gala", "clear")
		main.megaflock.set_level(3)
		main.music.act4_active = true
		main.megaflock.chorus = 1.0
		await _settle(4.0)
		main.fireworks.set_palette([Color(1.0, 0.82, 0.4), Color(0.95, 0.97, 1.0), Color(0.95, 0.4, 0.5), Color(0.5, 0.75, 1.0)])
		for x in [-13.0, -6.0, 0.5, 7.0, 13.0]:
			main.fireworks.launch(Vector3(x, 0, randf_range(-30, -22)))
		_hand(Vector3(0.02, 0.32, -0.98))
		await _settle(1.75)
		_aim(eye, Vector3(0, 3.1, -8.0), 80.0)
		await _settle(0.05)
		await _save("09_finale")
	if _ok("10_portrait"):
		_stage("cygne", 45.0, "golden", "clear")
		main.flock.set_formation("free")
		main.flock.set_process(false)
		for o in main.flock.swans:
			o.global_position = Vector3(40, -5, 40)
		var s: Swan = main.flock.swans[0]
		s.flying = false
		s.flap_phase = -1.0
		s.tgt_wing = 0.0
		s.pose_wing = 0.0
		s._flourish = 0.0
		s.global_position = Vector3(0, 0, -6.8)
		s.heading = -PI * 0.58
		s.rotation = Vector3(0, s.heading, 0)
		s.dance_gain = 0.4
		s.speed = 0.0
		for i in 40:
			s.update_swan(0.03, 11.0)
			s.speed = 0.0
			s.global_position = Vector3(0, 0, -6.8)
			await get_tree().process_frame
		var p: Vector3 = s.global_position
		main.conductor.desktop_tip = Vector3.ZERO
		_aim(p + Vector3(0.15, 0.72, 1.95), p + Vector3(0.1, 0.50, 0), 36.0)
		await _settle(0.3)
		await _save("10_portrait")
	print("STILLS_DONE")
	get_tree().quit()
