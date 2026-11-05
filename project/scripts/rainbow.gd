class_name Rainbow
extends Node
# The arc you paint after the storm. Physically placed opposite the sun's side of the sky, and
# drawn as one additive strip you can see through, so it costs little overdraw.

var main
var mi: MeshInstance3D
var mat: ShaderMaterial
var alpha := 0.0
var target := 0.0
var peak_alpha := 0.0
const R_ := 92.0

func setup(m) -> void:
	main = m
	mi = MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 48
	for i in segs:
		for k in 2:
			var u0 := float(i) / segs
			var u1 := float(i + 1) / segs
			var a0 := lerpf(deg_to_rad(8.0), deg_to_rad(172.0), u0)
			var a1 := lerpf(deg_to_rad(8.0), deg_to_rad(172.0), u1)
			var r0 := R_ * (0.86 + 0.14 * float(k) * 0.5)
			var r1 := R_ * (0.86 + 0.14 * float(k + 1) * 0.5)
			var p := [Vector3(-cos(a0) * r0, sin(a0) * r0, 0), Vector3(-cos(a1) * r0, sin(a1) * r0, 0),
				Vector3(-cos(a1) * r1, sin(a1) * r1, 0), Vector3(-cos(a0) * r1, sin(a0) * r1, 0)]
			var v := [float(k) * 0.5, float(k) * 0.5, float(k + 1) * 0.5, float(k + 1) * 0.5]
			var uu := [u0, u1, u1, u0]
			# Godot front faces are clockwise. Seen from the dock (+Z), this ordering points
			# toward the audience; the old counter-clockwise order was back-facing and only
			# survived because the shader disabled culling globally.
			for j in [0, 2, 1, 0, 3, 2]:
				st.set_uv(Vector2(uu[j], v[j]))
				st.add_vertex(p[j])
	mi.mesh = st.commit()
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/rainbow.gdshader")
	mi.material_override = mat
	mi.position = Vector3(6, -6, -118)
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(mi)

func set_target(v: float) -> void:
	target = v

func set_bins(bins: PackedByteArray, auto: float) -> void:
	# Lit outward from where you've swept. The auto level still finishes it for anyone
	# who just watches.
	var mask := 0.0
	var n := bins.size()
	var bits := PackedFloat32Array()
	bits.resize(n)
	for i in n:
		bits[i] = maxf(float(bins[i]), auto)
	mat.set_shader_parameter("bins", bits)

func _process(delta: float) -> void:
	alpha = lerpf(alpha, target, clampf(delta * 1.2, 0.0, 1.0))
	mi.visible = alpha > 0.01
	peak_alpha = maxf(peak_alpha, alpha)
	mat.set_shader_parameter("alpha", alpha)
