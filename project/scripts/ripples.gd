class_name RippleField
extends Node
# Fixed pool of ripple events uploaded to the water shader each frame.

const MAX := 16

var water_mat: ShaderMaterial
var slots: Array[Vector4] = []
var cursor := 0
var now := 0.0

func _ready() -> void:
	slots.resize(MAX)
	for i in MAX:
		slots[i] = Vector4.ZERO

func add(pos: Vector3, strength: float) -> void:
	slots[cursor] = Vector4(pos.x, pos.z, now, strength)
	cursor = (cursor + 1) % MAX

func tick(t: float) -> void:
	now = t
	var arr := PackedVector4Array()
	arr.resize(MAX)
	for i in MAX:
		var s := slots[i]
		if s.w > 0.0 and t - s.z > 6.0:
			slots[i] = Vector4.ZERO
			s = Vector4.ZERO
		arr[i] = s
	water_mat.set_shader_parameter("u_ripples", arr)
