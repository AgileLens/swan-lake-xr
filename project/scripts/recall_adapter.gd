extends "res://scripts/recall_menu.gd"
var main
func setup(m) -> void:
	main = m
	head_pose = _head
	sample_hand = _sample
	available = _available
	on_open = _open_menu
	on_close = _close_menu
	on_action = _action
	acknowledge = _ack

var was_menu_open := false
func _head() -> Transform3D: return main.head_transform()
func _available() -> bool: return main.launch_menu != null and not main.launch_menu.open
func _sample(hand: String) -> Dictionary:
	var p: Transform3D = main.hand_input.pose(hand)
	return {"hand": hand, "active": main.hand_input.active(hand), "held": main.hand_input.pinch_pressed(hand), "point": p.origin, "origin": p.origin, "dir": -p.basis.z}
func _open_menu() -> void:
	was_menu_open = main.menu.open
	if not main.menu.open: main.menu.toggle()
func _close_menu() -> void:
	if main.menu.open != was_menu_open: main.menu.toggle()
func _action(s: Dictionary) -> void:
	if main.menu.try_tap(Transform3D(Basis.looking_at(s.dir, Vector3.UP), s.origin)):
		if main.hand_input.source[s.hand] == main.hand_input.Src.CONTROLLER:
			main.haptic_controller(main.hand_input.controller(s.hand), 0.32, 0.035)
func _ack(hand: String) -> void:
	if main.hand_input.source[hand] == main.hand_input.Src.CONTROLLER:
		main.haptic_controller(main.hand_input.controller(hand), 0.32, 0.035)
	main.audio.play2d("chime_1", -12.0, 1.4)
