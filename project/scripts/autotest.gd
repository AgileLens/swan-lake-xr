extends Node
# --autotest[=conduct|off|wild]: runs the whole program through the real handlers on a virtual
# clock. Not a headset test: no audio plays and nothing is judged by eye.
#   conduct: a baton beats time on the beat map, and uses each movement's gesture.
#   off:     nobody touches anything. The program must still finish and bow.
#   wild:    random flailing. Must never score below doing nothing.
# Writes out/autotest_<mode>.json and exits nonzero on failure.
var main
var mode := "conduct"
var failures: Array[String] = []
var checks := 0
var started: Array[String] = []
var ended := {}
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _beat_i := 0
var _finished := false
var _result := {}
var _star_t := 0.0
var _curtain_seen_t := -1.0
var fw_launches := 0
var _gather_pressed := false
var _deadline := 2400.0
var _triggers := 0

func setup(m) -> void:
	main = m
	rng.seed = 42
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest="):
			mode = a.substr(11)
	main.music.virtual_clock = true
	main.perf.enabled = false
	main.title.skip_intro()
	main.program.movement_started.connect(func(i): started.append(ProgramData.MOVEMENTS[i]["id"]))
	main.program.movement_ended.connect(func(i, g): ended[ProgramData.MOVEMENTS[i]["id"]] = g)
	main.program.program_finished.connect(_on_finished)
	main.program.start()
	print("[autotest] mode=", mode)

func expect(name: String, ok: bool, detail := "") -> void:
	checks += 1
	if ok:
		print("PASS ", name)
	else:
		failures.append(name)
		print("FAIL ", name, " ", detail)

func _on_finished(grace: float, tier: int) -> void:
	_finished = true
	_result = {"mode": mode, "grace": grace, "tier": tier, "grades": main.program.grades,
		"ictus": main.program.ictus_count, "on_beat": main.program.on_beat_count,
		"woken": main.flock.awake_count(), "strikes": main.storm.player_strikes,
		"stars": main.constellation.count_lit(), "done_cygnus": main.constellation.done}
	_curtain_seen_t = _t

func _process(delta: float) -> void:
	_t += delta
	if _finished:
		if _t - _curtain_seen_t > 3.0:
			_finish()
		return
	if _t > _deadline:
		expect("program reached the curtain before the deadline", false, "stuck at " + str(main.program.movement.get("id")))
		_finish()
		return
	_drive(delta)

func _head() -> Vector3:
	return main.head_transform().origin

func _drive(delta: float) -> void:
	if mode == "off":
		main.conductor.desktop_tip = Vector3.ZERO
		return
	var prog = main.program
	if prog.state != ConductorsProgram.State.PLAY:
		main.conductor.desktop_tip = _head() + Vector3(0.25, -0.2, -0.55)
		return
	var verb: String = prog.movement["verb"]
	if mode == "wild":
		_wild(delta)
		return
	var music = main.music
	var phase: float = music.beat_phase()
	# A real conducting stroke: fall to the ictus on the beat, rebound up.
	var fall := -cos(phase * TAU) * 0.5 + 0.5
	var pos: Vector3 = _head() + Vector3(0.22, -0.32 + (1.0 - fall) * 0.0, -0.6)
	var stroke := absf(0.5 - phase) * 2.0 * 0.28
	pos.y += stroke
	match verb:
		"raise":
			pos.y += 0.32
		"lead":
			pos.x += sin(main.t * 0.35) * 0.45
			pos.y -= 0.2
		"strike":
			pos.y += stroke
		"paint":
			pos = _head() + Vector3(sin(main.t * 1.3) * 0.55, -0.05 + stroke * 0.3, -0.6)
		"legato":
			pos = _head() + Vector3(sin(main.t * 0.4) * 0.3, -0.4, -0.6)
		"stars":
			_star_t += delta
			if _star_t > 8.0:
				_star_t = 0.0
				_press_star()
		"gather":
			if not main.gather_on:
				main.gather_point = Vector3(0, 0, -6.5)
				main.set_gather(true)
		"launch":
			pos.y -= 0.12
	main.conductor.desktop_tip = pos

func _wild(delta: float) -> void:
	main.conductor.desktop_tip = _head() + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.3), rng.randf_range(-0.8, -0.3))
	if rng.randf() < delta * 2.0:
		_triggers += 1
		main.press_primary(main.baton_aim_pose(), rng.randf() < 0.7)
	if rng.randf() < delta * 0.1:
		main.set_gather(not main.gather_on)

func _press_star() -> void:
	# Through the real handler, by aiming a pose at the first unlit star.
	var c = main.constellation
	for i in c.stars.size():
		if not c.lit[i]:
			var h: Vector3 = _head()
			var pose := Transform3D(Basis.looking_at((c.stars[i].global_position - h).normalized(), Vector3.UP), h)
			main.press_primary(pose, true)
			return

func _finish() -> void:
	var ids: Array[String] = []
	for m in ProgramData.MOVEMENTS:
		ids.append(m["id"])
	expect("every movement started, in order", started == ids, str(started))
	expect("every movement ended", ended.size() == ids.size(), str(ended.keys()))
	expect("program reached the curtain", main.program.state == ConductorsProgram.State.CURTAIN, str(main.program.state))
	expect("the flock is taking its bow in a line", main.flock.formation == "curtain")
	expect("feathers are falling", main.feathers.p.emitting)
	expect("the rainbow was painted at some point", main.rainbow.peak_alpha > 0.5, str(main.rainbow.peak_alpha))
	expect("Cygnus always completes", main.constellation.done, str(main.constellation.count_lit()))
	expect("all swans are awake", main.flock.awake_count() == 8, str(main.flock.awake_count()))
	var grace: float = _result.get("grace", 0.0)
	expect("grace is at or above the floor", grace >= ConductLogic.GRADE_FLOOR - 0.0001, str(grace))
	var fp := "res://../out/autotest_%s.json" % mode
	var f := FileAccess.open(fp, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_result))
		f.close()
	if mode == "conduct":
		expect("a baton on the beat lands beats", int(_result.get("on_beat", 0)) > 100, str(_result.get("on_beat", 0)))
		expect("your downstrokes called lightning", main.storm.player_strikes >= 3, str(main.storm.player_strikes))
		expect("you lit stars yourself", int(_result.get("stars", 0)) >= 5, str(_result.get("stars", 0)))
		_compare_with("off", true)
		expect("a full performance earned more than warm applause", int(_result.get("tier", 0)) >= 2, str(_result))
	if mode == "off":
		expect("nobody conducting still gets the bow", int(_result.get("tier", -1)) >= 0)
		expect("no ictus without a baton", int(_result.get("ictus", 1)) == 0, str(_result.get("ictus", 1)))
		expect("the storm still struck on its own", main.storm.strikes >= 3, str(main.storm.strikes))
	if mode == "wild":
		_compare_with("off", false)
		expect("no wild gesture fell below the floor", _min_grade() >= ConductLogic.GRADE_FLOOR - 0.0001, str(_result.get("grades", [])))
	print("AUTOTEST_RESULT mode=%s checks=%d failures=%d grace=%.3f tier=%d" % [mode, checks, failures.size(), grace, int(_result.get("tier", -1))])
	print("AUTOTEST " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(1 if failures.size() > 0 else 0)

func _min_grade() -> float:
	var m := 1.0
	for g in _result.get("grades", []):
		m = minf(m, float(g))
	return m

func _compare_with(other: String, strict: bool) -> void:
	var fp := "res://../out/autotest_%s.json" % other
	if not FileAccess.file_exists(fp):
		print("     (no ", other, " run on disk to compare with)")
		return
	var o: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fp))
	var a: float = _result.get("grace", 0.0)
	var b: float = o.get("grace", 0.0)
	if strict:
		expect("conducting beats not conducting", a > b + 0.1, "%f vs %f" % [a, b])
	else:
		expect("flailing is never worse than doing nothing", a >= b - 0.0001, "%f vs %f" % [a, b])
