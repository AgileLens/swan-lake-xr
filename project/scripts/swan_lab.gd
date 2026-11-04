extends Node
# --swanlab <outdir>: close-up and dock-distance renders of the hero bird, with the real
# scene and the Mobile renderer. It exists to test the visible defect at the app's real
# distances. It does not ship in any user flow.
var main
var vp: SubViewport
var cam: Camera3D
var out_dir := ""

func setup(m) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://../out/swanlab")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in DirAccess.get_files_at(out_dir):
		DirAccess.remove_absolute(out_dir.path_join(f))
	vp = SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.world_3d = main.get_viewport().find_world_3d()
	add_child(vp)
	cam = Camera3D.new()
	cam.near = 0.02
	cam.far = 800.0
	vp.add_child(cam)
	cam.make_current()
	_run()

func _shot(n: String, pos: Vector3, target: Vector3, fov := 60.0) -> void:
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	main.reflections.override_eye = cam.global_transform
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out_dir.path_join(n + ".png"))
	print("[lab] ", n)

func _hold(s: Swan, p: Vector3, heading: float) -> void:
	s.set_meta("hold", p)
	s.global_position = p
	s.heading = heading
	s.rotation = Vector3(0, heading, 0)

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	main.perf.enabled = false
	main.title.skip_intro()
	main.flock.set_process(false)
	main.mood.apply("night", true)
	for s in main.flock.swans:
		s.global_position = Vector3(0, -30, 0)
	var a: Swan = main.flock.swans[0]
	var b: Swan = main.flock.swans[1]
	a.scale = Vector3.ONE
	var pa := Vector3(0.0, 0.0, -3.0)
	_hold(a, pa, 0.5)
	await _freeze(a, 0.016)
	# What the wearer sees: eye height on the dock, at the distances the flock really swims.
	var eye := Vector3(0, 1.70, 0.6)
	await _shot("night_dock_3m6", eye, pa + Vector3(0, 0.3, 0), 75.0)
	await _shot("night_close_side", pa + Vector3(1.6, 0.55, 0.7), pa + Vector3(0, 0.45, 0), 45.0)
	await _shot("night_head", pa + Vector3(0.55, 1.0, -0.15), pa + Vector3(-0.15, 0.88, -0.4), 40.0)
	main.mood.apply("dawn", true)
	await _settle()
	await _shot("dawn_dock_3m6", eye, pa + Vector3(0, 0.3, 0), 75.0)
	await _shot("dawn_close_side", pa + Vector3(1.6, 0.55, 0.7), pa + Vector3(0, 0.45, 0), 45.0)
	await _shot("dawn_three_q_rear", pa + Vector3(1.0, 0.8, 1.6), pa + Vector3(0, 0.35, 0), 45.0)
	await _shot("dawn_top", pa + Vector3(0.9, 2.2, 0.5), pa + Vector3(0, 0.2, -0.1), 45.0)
	await _shot("dawn_side_pure", pa + Vector3(2.2, 0.45, -1.0), pa + Vector3(0, 0.42, 0), 35.0)
	await _shot("dawn_head", pa + Vector3(0.55, 1.0, -0.15), pa + Vector3(-0.15, 0.88, -0.4), 40.0)
	# Pose sheet.
	var poses := [["rest", {}], ["tall", {"tgt_tall": 1.0}], ["sleep", {"tgt_sleep": 1.0}],
		["heart", {"tgt_heart": 1.0}], ["busk", {"tgt_wing": 0.5}], ["spread", {"tgt_wing": 1.0, "tgt_tall": 1.0}]]
	for p in poses:
		a.tgt_tall = p[1].get("tgt_tall", 0.0)
		a.tgt_sleep = p[1].get("tgt_sleep", 0.0)
		a.tgt_heart = p[1].get("tgt_heart", 0.0)
		a.tgt_wing = p[1].get("tgt_wing", 0.0)
		await _freeze(a, 0.3, 40)
		await _shot("pose_" + p[0], pa + Vector3(2.0, 0.8, 1.3), pa + Vector3(0, 0.5, 0), 50.0)
	a.tgt_wing = 0.0; a.tgt_tall = 0.0
	print("[lab] tris ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("LAB_DONE")
	get_tree().quit()

func _settle() -> void:
	for i in 6:
		await get_tree().process_frame

func _freeze(s: Swan, dt: float, n := 1) -> void:
	var p: Vector3 = s.global_position
	var h: float = s.heading
	for i in n:
		s.speed = 0.0
		s.dance_gain = 0.0
		s.update_swan(dt, 10.0)
		s.global_position = p
		s.heading = h
		s.rotation = Vector3(0, h, 0)
		await get_tree().process_frame
	s.global_position = p
