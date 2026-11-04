class_name MusicStand
extends Node
# A real music stand on the dock, in front of you and a little below your eyes. It's the only
# text surface in the program: what's playing, who is playing it, where it came from, and what
# your baton does right now. It stays out of the view of the lake unless you look down at it.

var main  # SwanLakeMain
var root: Node3D
var sheet: Node3D
var pole: MeshInstance3D
var title_l: Label3D
var piece_l: Label3D
var credit_l: Label3D
var hint_l: Label3D
var rosettes_l: Label3D
var next_orb: MeshInstance3D
var next_l: Label3D
var progress: MeshInstance3D
var grades := {}
const POS := Vector3(-0.24, 0, -0.02)
const ROSETTE_GLYPHS := ["·", "○", "◉", "✦"]

func setup(m) -> void:
	main = m
	root = Node3D.new()
	root.position = POS
	main.add_child(root)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.03, 0.03, 0.035)
	black.metallic = 0.6
	black.roughness = 0.42
	pole = MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.009
	pm.bottom_radius = 0.012
	pm.height = 1.0
	pm.radial_segments = 8
	pole.mesh = pm
	pole.material_override = black
	root.add_child(pole)
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.02
	bm.bottom_radius = 0.17
	bm.height = 0.03
	bm.radial_segments = 12
	base.mesh = bm
	base.material_override = black
	base.position = Vector3(0, 0.365, 0)
	root.add_child(base)
	sheet = Node3D.new()
	root.add_child(sheet)
	# Turned to face a wearer standing at the dock's center line.
	sheet.rotation_degrees = Vector3(-34, -22, 0)
	var desk := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.41, 0.27, 0.008)
	desk.mesh = dm
	desk.material_override = black
	desk.position = Vector3(0, 0, -0.006)
	sheet.add_child(desk)
	var ledge := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.41, 0.008, 0.035)
	ledge.mesh = lm
	ledge.material_override = black
	ledge.position = Vector3(0, -0.14, 0.012)
	sheet.add_child(ledge)
	var page := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.385, 0.25)
	page.mesh = qm
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.86, 0.83, 0.74)
	paper.roughness = 0.9
	# The score lamp: legible at midnight without lighting the rest of the dock.
	paper.emission_enabled = true
	paper.emission = Color(0.62, 0.57, 0.46)
	paper.emission_energy_multiplier = 0.55
	page.material_override = paper
	page.position = Vector3(0, 0, 0.0)
	sheet.add_child(page)
	title_l = _text(40, Vector3(0, 0.094, 0.002), Color(0.08, 0.06, 0.05))
	piece_l = _text(17, Vector3(0, 0.048, 0.002), Color(0.14, 0.11, 0.09))
	credit_l = _text(12, Vector3(0, 0.010, 0.002), Color(0.26, 0.22, 0.18))
	hint_l = _text(18, Vector3(0, -0.046, 0.002), Color(0.28, 0.10, 0.08))
	rosettes_l = _text(19, Vector3(0, -0.098, 0.002), Color(0.14, 0.11, 0.09))
	progress = MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(1, 0.003)
	progress.mesh = pq
	var pr := StandardMaterial3D.new()
	pr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pr.albedo_color = Color(0.28, 0.10, 0.08)
	progress.material_override = pr
	progress.position = Vector3(-0.175, -0.118, 0.003)
	sheet.add_child(progress)
	# Turn the page: a small brass knob you can tap with the baton.
	next_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.024
	sm.height = 0.048
	next_orb.mesh = sm
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.72, 0.56, 0.28)
	brass.metallic = 0.8
	brass.roughness = 0.34
	brass.emission_enabled = true
	brass.emission = Color(0.8, 0.6, 0.25)
	brass.emission_energy_multiplier = 0.15
	next_orb.material_override = brass
	next_orb.position = Vector3(0.236, -0.09, 0.02)
	sheet.add_child(next_orb)
	next_l = _text(11, Vector3(0.236, -0.128, 0.01), Color(0.72, 0.68, 0.58))
	next_l.text = "next"
	fit_to_head()
	show_title()

func _text(size: int, pos: Vector3, c: Color) -> Label3D:
	var l := Label3D.new()
	l.font_size = size
	l.outline_size = 0
	l.pixel_size = 0.0007
	l.modulate = c
	l.position = pos
	l.width = 510.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.no_depth_test = false
	l.shaded = false
	l.double_sided = false
	sheet.add_child(l)
	return l

func fit_to_head() -> void:
	# Seated or standing, the page sits 50 cm below the eyes, within arm's reach.
	var head_y: float = main.head_transform().origin.y
	var page_y := clampf(head_y - 0.50, 0.70, 1.40)
	sheet.position = Vector3(0, page_y, 0)
	pole.position = Vector3(0, (page_y + 0.35) * 0.5, 0)
	pole.scale = Vector3(1, maxf(page_y - 0.35, 0.1), 1)

func show_title() -> void:
	title_l.text = "The Conductor's Program"
	piece_l.text = "A lake, a flock, and your hand"
	credit_l.text = "An Agile Lens production"
	hint_l.text = ""
	rosettes_l.text = ""

func show_movement(i: int) -> void:
	fit_to_head()
	var m: Dictionary = ProgramData.MOVEMENTS[i]
	var num: String = m["numeral"]
	title_l.text = (num + ". " if num != "" else "") + str(m["title"])
	piece_l.text = "%s\n%s" % [m["piece"], m["composer"]]
	credit_l.text = "%s\n%s" % [m["performer"], m["source"]]
	hint_l.text = m["hint"]
	_refresh_rosettes()

func _refresh_rosettes() -> void:
	var s := ""
	for i in ProgramData.MOVEMENTS.size():
		if ProgramData.MOVEMENTS[i]["numeral"] == "":
			continue
		s += _glyph(grades.get(i, -1.0)) + "  "
	rosettes_l.text = s.strip_edges()

static func _glyph(g: float) -> String:
	if g < 0.0:
		return "-"
	if g < 0.42:
		return "○"
	if g < 0.62:
		return "◉"
	return "✦"

func rosette(i: int, g: float) -> void:
	grades[i] = g
	_refresh_rosettes()

func tick_progress(u: float, _grade: float) -> void:
	var w := 0.35 * clampf(u, 0.0, 1.0)
	progress.scale = Vector3(maxf(w, 0.001), 1, 1)
	progress.position.x = -0.175 + w * 0.5

func show_curtain(t: Dictionary, grace: float) -> void:
	title_l.text = str(t["name"])
	piece_l.text = str(t["line"])
	credit_l.text = "Grieg, Handel, Beethoven, Saint-Saëns, Smetana, Tchaikovsky\nPerformers and sources are in the app's credits"
	hint_l.text = "Tap the knob to stay on the lake."
	progress.scale = Vector3(0.001, 1, 1)
	_refresh_rosettes()

func show_free() -> void:
	title_l.text = "Stay on the lake"
	piece_l.text = "Your flock, your water, your baton"
	credit_l.text = "Moonlight from Vltava: Smetana, Musopen Symphony"
	hint_l.text = "Trigger ripples, grip gathers, left trigger launches. Tap the knob for an encore."

func aimed_next(t: Transform3D) -> bool:
	var dir := -t.basis.z
	var to := next_orb.global_position - t.origin
	return to.length() < 1.6 and dir.angle_to(to.normalized()) < deg_to_rad(6.0)

func try_tap(t: Transform3D) -> bool:
	if not aimed_next(t):
		return false
	main.audio.play2d("chime_3", -10.0)
	main.program.next_movement()
	return true
