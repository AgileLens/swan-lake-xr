extends SceneTree
var count := 0
var failed := false
func ok(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("FAIL " + message)
		quit(1)
		return
	count += 1
func _initialize() -> void:
	if not FileAccess.file_exists("res://scripts/recall_menu.gd"):
		print("FAIL no hands-only recall route")
		quit(1)
		return
	call_deferred("run")
func run() -> void:
	var menu = load("res://scripts/recall_menu.gd").new()
	root.add_child(menu)
	menu.set_process(false)
	menu.available = func(): return true
	var state := {"phase": "live", "progress": 37, "opens": 0, "closes": 0, "actions": 0, "acks": 0}
	menu.on_open = func(): state.opens += 1
	menu.on_close = func(): state.closes += 1
	menu.on_action = func(_s): state.actions += 1
	menu.acknowledge = func(_h): state.acks += 1
	var s := {"hand": "right", "active": true, "held": true, "point": Vector3.ZERO, "origin": Vector3(0,0,1), "dir": Vector3.FORWARD}
	menu.step([s])
	ok(not menu.open, "held Start cannot open recall")
	s.held = false; menu.step([s])
	var left := s.duplicate(); left.hand = "left"; left.held = true
	s.held = true; menu.step([s, left])
	ok(not menu.open, "two-hand gather/possession cannot be stolen by Menu")
	s.held = false; left.held = false; menu.step([s, left])
	s.point = Vector3(3,0,0); s.origin = Vector3(3,0,1); s.held = true; menu.step([s])
	ok(not menu.open, "pinch away from target cannot open menu")
	s.held = false; menu.step([s]); s.origin = Vector3(0,0,1)
	s.held = true; menu.step([s])
	ok(menu.open and state.opens == 1 and paused, "physical target opens modal and freezes gameplay")
	ok(state.actions == 0, "opening edge does not click through")
	for i in 5: menu.step([s])
	ok(state.opens == 1 and state.actions == 0, "held pinch cannot repeat")
	s.active = false; s.held = false; menu.step([s])
	ok(not menu.modal_ready(), "tracking loss is not a release")
	s.active = true; s.held = true; menu.step([s])
	ok(not menu.modal_ready(), "tracking regained while held stays disarmed")
	s.held = false; menu.step([s])
	ok(menu.modal_ready(), "tracked release arms modal")
	s.point = Vector3(3,0,0); s.origin = Vector3(3,0,1)
	s.held = true; menu.step([s])
	ok(state.actions == 1 and menu.open, "separate pinch routes to settings once")
	for i in 3: menu.step([s])
	ok(state.actions == 1, "settings held pinch cannot repeat")
	s.held = false; menu.step([s])
	s.point = Vector3.ZERO; s.origin = Vector3(0,0,1); s.held = true; menu.step([s])
	ok(menu.open and paused and menu.closing, "Resume waits for release before gameplay")
	s.held = false; menu.step([s])
	ok(not menu.open and not paused and state.closes == 1, "release resumes exactly once")
	ok(state.phase == "live" and state.progress == 37, "recall does not reset gameplay state")
	ok(state.acks == 2, "one acknowledgement per open/Resume")
	menu.step([s]); ok(state.opens == 1, "release does not reopen")
	menu.queue_free()
	print("menu recall checks: %d passed, 0 failed" % count)
	quit(1 if failed else 0)
