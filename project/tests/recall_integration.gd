extends SceneTree
var failed := false
var checks := 0
var main
func ok(value: bool, message: String) -> void:
	checks += 1
	if not value: failed = true; push_error("FAIL " + message)
func _initialize() -> void: call_deferred("run")
func snapshot() -> String:
	return var_to_str([main.program.state, main.program.index, main.program._state_t, main.program.grades])
func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 150:
		if main.get("recall") != null: break
		await process_frame
	ok(main.get("recall") != null, "shipping scene installs recall route")
	if failed: quit(1); return
	var menu = main.recall
	menu.set_process(false)
	main.launch_menu._begin(0)
	var before := snapshot()
	var save_path := "user://swan_program.cfg"
	var saved := FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	var s := {"hand": "right", "active": true, "held": false, "point": menu.global_position, "origin": menu.global_position + menu.global_basis.z, "dir": -menu.global_basis.z}
	menu.step([s]); s.held = true; menu.step([s])
	ok(menu.open and paused, "live scene opens hands-only overlay")
	ok(main.menu.open, "settings orbs accessible")
	ok(snapshot() == before, "opening preserves live state")
	await create_timer(0.12, true).timeout
	ok(snapshot() == before, "state stays frozen during menu")
	s.held = false; menu.step([s]); s.held = true; menu.step([s])
	ok(menu.closing and paused, "Resume cannot leak a held selection")
	s.held = false; menu.step([s])
	ok(not menu.open and not paused, "tracked release resumes")
	ok(snapshot() == before, "Resume preserves exact phase/progress")
	ok(not main.menu.open, "original menu state restored")
	ok((FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()) == saved, "recall does not write the save")
	print("recall integration: %d passed, %d failed" % [checks, 1 if failed else 0])
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)
