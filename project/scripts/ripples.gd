class_name RippleField
extends Node
# Pooled ripple events -> water shader. Each event carries randomized look params
# (frequency / travel speed / life / sharpness) so no two ripples read identical.

const MAX := 28

var water_mat: ShaderMaterial
var slots: Array[Vector4] = []
var params: Array[Vector4] = []
var cursor := 0
var now := 0.0

func _ready() -> void:
	slots.resize(MAX)
	params.resize(MAX)
	for i in MAX:
		slots[i] = Vector4.ZERO
		params[i] = Vector4(12, 1.6, 6.0, 1.0)

func add(pos: Vector3, strength: float, delay := 0.0) -> void:
	slots[cursor] = Vector4(pos.x, pos.z, now + delay, strength)
	params[cursor] = Vector4(
		randf_range(8.0, 16.0),    # ring frequency
		randf_range(1.25, 2.2),    # travel speed
		randf_range(4.0, 6.5),     # life seconds
		randf_range(0.7, 1.6))     # edge sharpness
	cursor = (cursor + 1) % MAX

func burst(pos: Vector3, strength: float) -> void:
	add(pos, strength)
	add(pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), strength * 0.55, 0.12)
	add(pos + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)), strength * 0.35, 0.26)

func tick(t: float) -> void:
	now = t
	var arr := PackedVector4Array(); arr.resize(MAX)
	var arr2 := PackedVector4Array(); arr2.resize(MAX)
	for i in MAX:
		var s := slots[i]
		if s.w > 0.0 and t - s.z > params[i].z:
			slots[i] = Vector4.ZERO
			s = Vector4.ZERO
		arr[i] = s
		arr2[i] = params[i]
	water_mat.set_shader_parameter("u_ripples", arr)
	water_mat.set_shader_parameter("u_ripples2", arr2)
