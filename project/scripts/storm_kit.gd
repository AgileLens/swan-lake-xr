class_name StormKit
extends Node
# Lightning on your downstroke. Deliberately gentle for a headset: no full-field strobe. A single
# soft lift of the sky and one branching bolt, rate limited to one every 1.6 s. A bright flash
# right in a wearer's eyes is a comfort and photosensitivity risk.

var main
var bolts: Array[MeshInstance3D] = []
var mat: StandardMaterial3D
var flash := 0.0
var _next := 0
var strikes := 0
var player_strikes := 0

func setup(m) -> void:
	main = m
	mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.85, 0.9, 1.0, 1.0)
	mat.disable_fog = true
	for i in 3:
		var b := MeshInstance3D.new()
		b.material_override = mat.duplicate()
		b.visible = false
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.add_child(b)
		bolts.append(b)

func strike(at: Vector3, by_player: bool) -> void:
	strikes += 1
	if by_player:
		player_strikes += 1
	var b := bolts[_next]
	_next = (_next + 1) % bolts.size()
	b.mesh = _bolt_mesh(at)
	b.visible = true
	var mm: StandardMaterial3D = b.material_override
	mm.albedo_color.a = 1.0
	var tw := create_tween()
	tw.tween_property(mm, "albedo_color:a", 0.25, 0.09)
	tw.tween_property(mm, "albedo_color:a", 0.75, 0.05)
	tw.tween_property(mm, "albedo_color:a", 0.0, 0.34)
	tw.tween_callback(func(): b.visible = false)
	flash = 0.34 if by_player else 0.16
	main.ripples.burst(Vector3(at.x, 0, at.z), 0.8 if by_player else 0.3)
	main.flock.startle()

func _bolt_mesh(at: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(at.x + randf_range(-5, 5), 42.0, at.z - randf_range(0, 6))
	_segment(st, top, Vector3(at.x, 0.1, at.z), 0.34, 5)
	return st.commit()

func _segment(st: SurfaceTool, a: Vector3, b: Vector3, w: float, depth: int) -> void:
	if depth == 0:
		var fwd := (a - b).normalized()
		var side := fwd.cross(Vector3(0, 0, 1)).normalized() * w
		for p in [a - side, a + side, b + side, a - side, b + side, b - side]:
			st.add_vertex(p)
		return
	var mid := (a + b) * 0.5
	var off := (a - b).length() * 0.16
	mid += Vector3(randf_range(-off, off), randf_range(-off * 0.3, off * 0.3), randf_range(-off, off))
	_segment(st, a, mid, w, depth - 1)
	_segment(st, mid, b, w * 0.9, depth - 1)
	if depth == 3 and randf() < 0.7:
		var end := mid + Vector3(randf_range(-9, 9), -randf_range(5, 13), randf_range(-5, 5))
		_segment(st, mid, end, w * 0.45, 2)

func _process(delta: float) -> void:
	if flash > 0.001:
		flash = maxf(flash - delta * 1.1, 0.0)
		main.sky_mat.set_shader_parameter("flash", flash)
