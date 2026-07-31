class_name ReflectionRig
extends Node
# Four water-reflection techniques behind one cycle button:
# 0 Analytic (moon streak + star glitter, cheapest)
# 1 Probe    (ReflectionProbe env: sky/moon/hills appear in the water)
# 2 Planar   (mirrored camera in a SubViewport — swans/beam/fireworks reflect; one
#             viewpoint shared by both eyes, so reflections sit at wrong disparity)
# 3 Planar stereo (a mirrored camera per eye — correct disparity, 2x the cost)
#
# Which of these looks best is a headset judgment call, hence the ladder rather
# than one choice. Stereo is last so the perf governor sheds it first.

const MODES := ["analytic", "probe", "planar", "planar stereo"]
const REFL_FOV := 95.0
const REFL_SIZE := 1024  # was 768; genuine GPU cost tied directly to a visible
                          # quality knob (reflection sharpness), unlike a blanket
                          # full-screen post effect — a good match for XR2-class
                          # mobile GPU headroom per the research brief
const PREVIEW_IPD := 0.063  # desktop-only stand-in so mode 3 is testable off-headset

var main  # SwanLakeMain
var mode := 0
var probe: ReflectionProbe
# index 0 = left/mono, 1 = right
var viewports: Array[SubViewport] = []
var refl_cams: Array[Camera3D] = []

func setup(m) -> void:
	main = m
	# Alex + Dax, in-headset: "planar stereo reflections and shadows look
	# great — have them on by default." Shadows already default on
	# (main.gd's moon.shadow_enabled = true); this makes stereo the default
	# reflection mode instead of analytic. The perf governor can still shed it
	# down through mono/probe/off if frame rate genuinely can't hold it.
	apply(3)

func mode_name() -> String:
	return MODES[mode]

func cycle() -> int:
	apply((mode + 1) % MODES.size())
	return mode

func planar_active() -> bool:
	return mode >= 2

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
	var want: int = 0 if mode < 2 else (1 if mode == 2 else 2)
	while viewports.size() < want:
		_add_eye()
	for i in viewports.size():
		var live: bool = i < want
		viewports[i].render_target_update_mode = \
			SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
	if want >= 1:
		main.water_mat.set_shader_parameter("planar_tex", viewports[0].get_texture())
	if want >= 2:
		main.water_mat.set_shader_parameter("planar_tex_r", viewports[1].get_texture())

func _add_eye() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(REFL_SIZE, REFL_SIZE)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	main.add_child(vp)
	var c := Camera3D.new()
	c.fov = REFL_FOV
	c.cull_mask = 1  # scene only: reticle/HUD live on other layers
	vp.add_child(c)
	vp.add_child(WorldEnvironment.new())
	viewports.append(vp)
	refl_cams.append(c)

func _eye_transform(view: int) -> Transform3D:
	if view < 0:
		return main.head_transform()  # mono: head center, both eyes share it
	if main.xr_active and main.origin:
		var iface := XRServer.find_interface("OpenXR")
		if iface and iface.is_initialized():
			return iface.get_transform_for_view(view, main.origin.global_transform)
	var head: Transform3D = main.head_transform()
	var dx: float = (float(view) - 0.5) * PREVIEW_IPD
	return head * Transform3D(Basis(), Vector3(dx, 0, 0))

func _mirror(view: int, cam: Camera3D, tex_param: String) -> void:
	var t: Transform3D = _eye_transform(view)
	# mirror the eye about the y=0 water plane
	var mp: Vector3 = t.origin
	mp.y = -mp.y
	var fwd: Vector3 = -t.basis.z
	fwd.y = -fwd.y
	var up: Vector3 = t.basis.y
	up.y = -up.y
	cam.global_transform = Transform3D(Basis.looking_at(fwd, up), mp)
	var vp_mat := Projection(cam.global_transform.affine_inverse())
	main.water_mat.set_shader_parameter(tex_param, cam.get_camera_projection() * vp_mat)

func _process(_d: float) -> void:
	if not planar_active() or refl_cams.is_empty():
		return
	# In mono planar the single camera tracks the head; in stereo each tracks its eye.
	if mode == 2:
		_mirror(-1, refl_cams[0], "refl_vp")
	else:
		_mirror(0, refl_cams[0], "refl_vp")
		if refl_cams.size() > 1:
			_mirror(1, refl_cams[1], "refl_vp_r")
