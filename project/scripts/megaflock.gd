class_name MegaFlock
extends Node
# The corps de ballet: thousands of instanced swans on the outer lake via two
# MultiMeshes (lowpoly mesh near, origami far) — a handful of draw calls total.
# Bob/sway runs in the vertex shader off per-instance phase; a round-robin batch
# drifts transforms so the mass slowly glides. Swells in at the finale.

const COUNTS: Array[int] = [0, 200, 800, 2000, 5000]
const NEAR_COUNT := 150          # instances that use the nicer mesh
const R_MIN := 17.0              # keep outside the hero flock's roam bounds
const R_MAX := 58.0

var main  # SwanLakeMain
var level := 0
var near_mmi: MultiMeshInstance3D
var far_mmi: MultiMeshInstance3D
var states: Array = []           # per instance: [angle, radius, drift_speed]
var _cursor := 0
var _prev_level_before_finale := -1
var _shader_mat: ShaderMaterial

func setup(m) -> void:
	main = m
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = load("res://shaders/corps.gdshader")
	near_mmi = _make_mmi("res://assets/swan_style1.glb")
	far_mmi = _make_mmi("res://assets/swan_style0.glb")

func _make_mmi(glb: String) -> MultiMeshInstance3D:
	var scene: PackedScene = load(glb)
	var inst: Node3D = scene.instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bake(inst, inst.global_transform.affine_inverse(), st)
	inst.queue_free()
	var mesh := st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _shader_mat
	mmi.visible = false
	main.add_child(mmi)
	return mmi

func _bake(node: Node, root_inv: Transform3D, st: SurfaceTool) -> void:
	if node is MeshInstance3D and node.mesh:
		var xf: Transform3D = node.global_transform
		for s in node.mesh.get_surface_count():
			st.append_from(node.mesh, s, xf)
	for c in node.get_children():
		_bake(c, root_inv, st)

func level_name() -> String:
	return "off" if COUNTS[level] == 0 else str(COUNTS[level])

func cycle() -> void:
	set_level((level + 1) % COUNTS.size())

func set_level(lv: int) -> void:
	level = clampi(lv, 0, COUNTS.size() - 1)
	var total := COUNTS[level]
	var near_n := mini(total, NEAR_COUNT)
	var far_n := total - near_n
	states.resize(total)
	_fill(near_mmi, near_n, 0)
	_fill(far_mmi, far_n, near_n)
	near_mmi.visible = near_n > 0
	far_mmi.visible = far_n > 0

func _fill(mmi: MultiMeshInstance3D, count: int, seed_off: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + seed_off
	mmi.multimesh.instance_count = count
	for i in count:
		var ang := rng.randf_range(0.0, TAU)
		# near instances hug the inner radius; far ones fill the whole annulus
		var r := rng.randf_range(R_MIN, R_MIN + 12.0) if seed_off == 0 \
			else rng.randf_range(R_MIN + 6.0, R_MAX)
		var drift := rng.randf_range(0.06, 0.16) * (1.0 if rng.randf() > 0.5 else -1.0)
		_apply_instance(mmi, i, ang, r, drift, rng)

func _apply_instance(mmi: MultiMeshInstance3D, i: int, ang: float, r: float, drift: float, rng: RandomNumberGenerator) -> void:
	var pos: Vector3 = main.LAKE_CENTER + Vector3(sin(ang) * r, 0.0, cos(ang) * r)
	# face tangentially (direction of drift)
	var heading := ang + (PI * 0.5 if drift > 0.0 else -PI * 0.5) + rng.randf_range(-0.4, 0.4)
	var basis := Basis(Vector3.UP, heading)
	var sc := rng.randf_range(0.85, 1.1)
	mmi.multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * sc), pos))
	# custom data: x = bob phase, y = bob rate
	mmi.multimesh.set_instance_custom_data(i, Color(rng.randf_range(0.0, TAU), rng.randf_range(0.7, 1.3), 0, 0))
	var idx := i if mmi == near_mmi else NEAR_COUNT + i
	if idx < states.size():
		states[idx] = [ang, r, drift]

func finale_swell() -> void:
	if COUNTS[level] == 0:
		_prev_level_before_finale = level
		set_level(2)  # 800 swans arrive for the finale

func relax() -> void:
	if _prev_level_before_finale >= 0:
		set_level(_prev_level_before_finale)
		_prev_level_before_finale = -1

func _process(delta: float) -> void:
	var total := COUNTS[level]
	if total == 0:
		return
	_shader_mat.set_shader_parameter("u_time", main.t)
	# round-robin drift: ~200 instances updated per frame keeps CPU flat at any count
	var batch := mini(200, total)
	for k in batch:
		var idx := (_cursor + k) % total
		var s = states[idx]
		if s == null:
			continue
		s[0] += s[2] * delta * float(total) / float(batch) * 0.016
		var near := idx < NEAR_COUNT and near_mmi.multimesh.instance_count > 0
		var mmi := near_mmi if near else far_mmi
		var i := idx if near else idx - NEAR_COUNT
		if i >= 0 and i < mmi.multimesh.instance_count:
			var t: Transform3D = mmi.multimesh.get_instance_transform(i)
			var pos: Vector3 = main.LAKE_CENTER + Vector3(sin(s[0]) * s[1], 0.0, cos(s[0]) * s[1])
			mmi.multimesh.set_instance_transform(i, Transform3D(t.basis, pos))
	_cursor = (_cursor + batch) % total
