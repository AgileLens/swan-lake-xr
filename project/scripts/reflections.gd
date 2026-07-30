class_name ReflectionRig
extends Node
# Three water-reflection techniques behind one cycle button:
# 0 Analytic (moon streak + star glitter, cheapest)
# 1 Probe    (ReflectionProbe env: sky/moon/hills appear in the water)
# 2 Planar   (experimental: mirrored mono camera SubViewport — swans/beam/fireworks reflect)

var main  # SwanLakeMain
var mode := 0
var probe: ReflectionProbe
var viewport: SubViewport
var refl_cam: Camera3D

func setup(m) -> void:
	main = m
	apply(0)

func mode_name() -> String:
	return ["analytic", "probe", "planar"][mode]

func cycle() -> int:
	apply((mode + 1) % 3)
	return mode

func apply(new_mode: int) -> void:
	mode = new_mode
	main.water_mat.set_shader_parameter("refl_mode", mode)
	main.water_mat.set_shader_parameter("water_metallic", 0.35 if mode == 1 else 0.0)
	if mode == 1 and probe == null:
		probe = ReflectionProbe.new()
		probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
		probe.size = Vector3(80, 24, 80)
		probe.origin_offset = Vector3(0, 6, 0)
		probe.position = Vector3(0, 6, -12)
		probe.intensity = 1.0
		main.add_child(probe)
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
	if probe:
		probe.visible = mode == 1
	if mode == 2 and viewport == null:
		viewport = SubViewport.new()
		viewport.size = Vector2i(768, 768)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		main.add_child(viewport)
		refl_cam = Camera3D.new()
		refl_cam.fov = 95.0
		refl_cam.cull_mask = 1  # scene only: reticle/HUD live on layer 3
		viewport.add_child(refl_cam)
		var we := WorldEnvironment.new()
		viewport.add_child(we)
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if mode == 2 else SubViewport.UPDATE_DISABLED
		if mode == 2:
			main.water_mat.set_shader_parameter("planar_tex", viewport.get_texture())

func _process(_d: float) -> void:
	if mode != 2 or refl_cam == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var t := cam.global_transform
	# mirror about y=0 water plane
	var mp := t.origin; mp.y = -mp.y
	var fwd := -t.basis.z; fwd.y = -fwd.y
	var up := t.basis.y; up.y = -up.y
	refl_cam.global_transform = Transform3D(Basis.looking_at(fwd, up), mp)
	var vp := Projection(refl_cam.global_transform.affine_inverse())
	var proj := refl_cam.get_camera_projection()
	main.water_mat.set_shader_parameter("refl_vp", proj * vp)
