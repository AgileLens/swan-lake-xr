class_name SwanLook
extends RefCounted
# Shared materials for the hero swan, so all eight birds batch on the same two materials.

static var body_mat: ShaderMaterial
static var feather_mat: ShaderMaterial

static func materials() -> void:
	if body_mat:
		return
	body_mat = ShaderMaterial.new()
	body_mat.shader = load("res://shaders/swan_body.gdshader")
	body_mat.set_shader_parameter("albedo_tex", load("res://assets/swan/swan_albedo.png"))
	body_mat.set_shader_parameter("normal_tex", load("res://assets/swan/swan_normal.png"))
	feather_mat = ShaderMaterial.new()
	feather_mat.shader = load("res://shaders/swan_feather.gdshader")
	feather_mat.set_shader_parameter("detail_tex", load("res://assets/swan/feather_detail.png"))

static func dress(model: Node) -> void:
	materials()
	_dress(model)

static func _dress(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var is_body := mi.skeleton != NodePath("") and mi.skin != null
		mi.material_override = body_mat if is_body else feather_mat
	for c in n.get_children(true):
		_dress(c)
