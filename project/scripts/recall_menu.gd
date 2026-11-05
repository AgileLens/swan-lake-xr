extends Node3D
## Always-reachable Menu/Resume target. Input is the same tracked pinch/trigger used by the app.
## Gameplay is paused until the closing pinch is visibly released; tracking loss never arms input.
var available: Callable
var sample_hand: Callable
var head_pose: Callable
var on_open: Callable
var on_close: Callable
var on_action: Callable
var acknowledge: Callable
var open := false
var closing := false
var armed := false
var waiting_release := true
var label: Label3D
var _was := {}
var _paused_before := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -75
	var tile := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = Vector3(0.20, 0.095, 0.012)
	tile.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.06, 0.10, 0.14)
	mat.no_depth_test = true
	tile.material_override = mat
	add_child(tile)
	label = Label3D.new(); label.text = "MENU · PINCH"
	label.font_size = 24; label.pixel_size = 0.00065
	label.no_depth_test = true; label.position.z = 0.012
	add_child(label)

func _process(_dt: float) -> void:
	visible = available.is_valid() and available.call()
	if not visible:
		armed = false
		return
	var h: Transform3D = head_pose.call()
	var f := -h.basis.z; f.y = 0
	if f.length() < 0.01: f = Vector3.FORWARD
	f = f.normalized()
	var right := f.cross(Vector3.UP)
	global_transform = Transform3D(Basis(right, Vector3.UP, -f), h.origin + f * 0.55 + right * 0.34 + Vector3.DOWN * 0.25)
	var samples := []
	for hand in ["left", "right"]:
		samples.append(sample_hand.call(hand))
	step(samples)

func hit(s: Dictionary) -> bool:
	if not s.get("active", false): return false
	var p: Vector3 = to_local(s.get("point", Vector3.INF))
	if absf(p.x) < 0.105 and absf(p.y) < 0.06 and absf(p.z) < 0.09: return true
	var o: Vector3 = to_local(s.get("origin", Vector3.INF))
	var d: Vector3 = global_basis.inverse() * s.get("dir", Vector3.ZERO)
	if absf(d.z) < 0.0001: return false
	var t := -o.z / d.z
	if t < 0 or t > 4: return false
	p = o + d * t
	return absf(p.x) < 0.105 and absf(p.y) < 0.06

func modal_ready() -> bool:
	return open and not waiting_release and not closing

func blocks_gameplay() -> bool:
	return open or (waiting_release and available.is_valid() and available.call())

func step(samples: Array) -> void:
	if not available.is_valid() or not available.call(): return
	var tracked := false
	var neutral := true
	var held_count := 0
	for s in samples:
		if s.get("active", false):
			tracked = true
			if s.get("held", false): neutral = false; held_count += 1
	if not tracked:
		armed = false
		waiting_release = true
		return
	if neutral:
		armed = true
		waiting_release = false
		_was.clear()
		if closing: _finish_close()
		return
	if not armed or waiting_release: return
	for s in samples:
		var hand: String = s.get("hand", "right")
		var held: bool = s.get("active", false) and s.get("held", false)
		var edge: bool = held and not _was.get(hand, false)
		_was[hand] = held
		if not edge: continue
		# A second held hand may be carrying a prop or gathering a flock. Never steal that gesture.
		if hit(s) and held_count == 1:
			acknowledge.call(hand)
			waiting_release = true
			armed = false
			if open:
				closing = true
				label.text = "RELEASE TO RESUME"
			else:
				open = true
				_paused_before = get_tree().paused
				get_tree().paused = true
				label.text = "RESUME · PINCH"
				on_open.call()
			return
		if modal_ready() and on_action.is_valid(): on_action.call(s)

func request_close() -> void:
	if not open: return
	closing = true
	waiting_release = true
	armed = false
	label.text = "RELEASE TO RESUME"

func _finish_close() -> void:
	on_close.call()
	open = false; closing = false
	get_tree().paused = _paused_before
	label.text = "MENU · PINCH"

func _exit_tree() -> void:
	if open and is_inside_tree(): get_tree().paused = _paused_before
