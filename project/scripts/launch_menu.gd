class_name SwanLaunchMenu
extends Node
# Opening program card. Aim and trigger/pinch/click; all input still routes through main.

var main
var root: Node3D
var panel: MeshInstance3D
var body: Label3D
var buttons: Array[Dictionary] = []
var theme: AudioStreamPlayer
var open := true

func setup(m) -> void:
	main = m
	_build()
	theme = AudioStreamPlayer.new()
	theme.bus = "Music"
	theme.stream = load("res://assets/music/menu_theme.wav")
	add_child(theme)
	if theme.stream is AudioStreamWAV:
		(theme.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(theme.stream as AudioStreamWAV).loop_end = (theme.stream as AudioStreamWAV).data.size() / 2
	theme.play()

func _mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.72
	if emission > 0.0:
		m.emission_enabled = true; m.emission = color; m.emission_energy_multiplier = emission
	return m

func _build() -> void:
	root = Node3D.new()
	root.position = Vector3(0, 1.55, -1.45)
	main.add_child(root)
	panel = MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = Vector3(1.05, 0.72, 0.035)
	panel.mesh = box; panel.material_override = _mat(Color(0.025, 0.055, 0.095, 0.96))
	root.add_child(panel)
	# Beveled/rounded silhouette made from cheap Mobile-renderer primitives.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var cap := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = 0.045; cm.bottom_radius = 0.045
			cm.height = 0.04; cm.radial_segments = 12
			cap.mesh = cm; cap.rotation_degrees.x = 90
			cap.position = Vector3(sx * 0.49, sy * 0.315, 0)
			cap.material_override = panel.material_override
			root.add_child(cap)
	_label("THE CONDUCTOR'S PROGRAM", 42, Vector3(0, 0.25, 0.03), Color(0.88, 0.94, 1.0))
	body = _label("Raise the lake with a baton. The program is kind, automatic, and yours to shape.\nHands and controllers may be used at any time.", 16, Vector3(0, 0.10, 0.03), Color(0.75, 0.84, 0.92))
	body.width = 880; body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_button("start", "START PROGRAM", Vector3(-0.31, -0.12, 0.045))
	_add_button("continue", "CONTINUE", Vector3(0.31, -0.12, 0.045))
	_add_button("instructions", "INSTRUCTIONS", Vector3(0, -0.25, 0.045))
	for i in 5:
		var feather := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.018 + i * 0.004; sm.height = sm.radius * 2.0
		feather.mesh = sm; feather.scale = Vector3(0.35, 1.0, 0.18)
		feather.position = Vector3(-0.18 + i * 0.09, 0.345 + sin(i * 1.7) * 0.015, 0.04)
		feather.rotation_degrees.z = -28 + i * 14
		feather.material_override = _mat(Color(0.72, 0.88, 1.0), 0.5)
		root.add_child(feather)
	_refresh_continue()

func _label(text: String, size: int, pos: Vector3, color: Color) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font_size = size; l.pixel_size = 0.0022
	l.position = pos; l.modulate = color; l.shaded = false
	root.add_child(l)
	return l

func _add_button(id: String, text: String, pos: Vector3) -> void:
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.36 if id != "instructions" else 0.44, 0.075, 0.025)
	plate.mesh = bm; plate.position = pos; plate.material_override = _mat(Color(0.12, 0.30, 0.45), 0.25)
	root.add_child(plate)
	var l := _label(text, 17, pos + Vector3(0, 0, 0.018), Color.WHITE)
	buttons.append({"id": id, "plate": plate, "label": l, "enabled": true})

func _refresh_continue() -> void:
	for b in buttons:
		if b.id == "continue":
			b.enabled = main.has_saved_program()
			b.label.modulate = Color.WHITE if b.enabled else Color(0.35, 0.42, 0.48)

func aimed_button(pose: Transform3D):
	if not open:
		return null
	var from := pose.origin; var dir := -pose.basis.z
	for b in buttons:
		if not b.enabled: continue
		var to: Vector3 = b.plate.global_position - from
		if to.length() < 4.0 and dir.angle_to(to.normalized()) < deg_to_rad(7.5):
			return b
	return null

func try_tap(pose: Transform3D) -> bool:
	var b = aimed_button(pose)
	if b == null: return false
	match b.id:
		"start": _begin(0)
		"continue": _begin(main.saved_program_index())
		"instructions":
			body.text = "RIGHT HAND / TRIGGER OR PINCH: conduct, ripple, and select.\nLEFT TRIGGER OR PINCH: firework. GRIP / BOTH PINCHES: gather.\nThe music never waits and gestures never lower your result. Y opens settings."
	main.audio.play2d("chime_2", -12.0, 1.2)
	return true

func _begin(index: int) -> void:
	open = false
	main.title.skip_intro()
	theme.stop()
	root.queue_free()
	main.program.start(index)

func _process(_delta: float) -> void:
	if not open: return
	for b in buttons:
		var hot := false
		for hand in main.HANDS:
			if main.hand_input.active(hand) and aimed_button(main.hand_input.pose(hand)) == b:
				hot = true; break
		b.plate.scale = Vector3.ONE * (1.06 if hot else 1.0)
