class_name PerfGovernor
extends Node
# Holds 72fps: watches average fps, steps down expensive features one notch at a time.
# One-way ladder (no flapping); HUD shows fps + tier when enabled.

var main  # SwanLakeMain
var hud: Label3D
var hud_on := false
var samples: Array[float] = []
var eval_timer := 3.0
var tier := 0  # 0 = everything on; each step disables one thing
var grace := 8.0  # let startup settle
# Desktop look-dev renders far below 72fps, so the governor would strip the very
# features a capture is meant to show. Off for --shot; always on in a headset.
var enabled := true
var _log_t := 0
var _sky_cheap := false
# Once every rung is exhausted, stop calling _step_down() forever — on real
# device hardware tonight this ran to tier=404+ with zero effect because fps
# was pinned below target by a cost nothing in the ladder touched (the sky
# shader — see sky_cheap below). A tier that climbs without bound is also
# useless in the HUD. exhausted latches once the match's last case fires.
var _exhausted := false

func setup(m) -> void:
	main = m
	hud = Label3D.new()
	hud.font_size = 20
	hud.pixel_size = 0.0025
	hud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hud.position = Vector3(-1.3, 2.4, -3.0)
	hud.visible = false
	main.add_child(hud)

func set_hud(on: bool) -> void:
	hud_on = on
	hud.visible = on

func _process(delta: float) -> void:
	grace = maxf(grace - delta, 0.0)
	var fps := Engine.get_frames_per_second()
	samples.append(fps)
	if samples.size() > 240:
		samples.pop_front()
	eval_timer -= delta
	if eval_timer <= 0.0:
		eval_timer = 2.0
		var avg := 0.0
		for s in samples:
			avg += s
		avg /= maxf(samples.size(), 1)
		if hud_on:
			hud.text = "fps %d | tier %d | refl %s | corps %s | flies %d | in L:%s R:%s" % [
				int(avg), tier, main.reflections.mode_name(), main.megaflock.level_name(),
				main.fireflies.particles.amount,
				main.hand_input.source_name("left"), main.hand_input.source_name("right")]
		# Android's gfxinfo reports zero frames for this app — Godot renders through
		# its own Vulkan/XR swapchain, not Choreographer — so the engine's own
		# counters are the only way to profile from outside the headset.
		_log_t += 1
		if _log_t >= 3:
			_log_t = 0
			print("[perf] fps=%.1f tier=%d refl=%s draws=%d prims=%d vram=%.1fMB" % [
				avg, tier, main.reflections.mode_name(),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
		if enabled and not _exhausted and grace <= 0.0 and avg < 71.0:
			_step_down()
			samples.clear()

func _step_down() -> void:
	# The corps is the single biggest lever — shed it level by level first.
	if main.megaflock.level > 1:
		main.megaflock.set_level(main.megaflock.level - 1)
		return
	# Fireflies (2500 default) are the second-biggest addition — shed a tier at
	# a time down to the original 130 before touching anything else.
	if main.fireflies.step_down_amount():
		return
	# Reflections can shed more than once (stereo planar → mono planar → probe),
	# so each call sheds exactly one thing and only advances the tier when the
	# reflection ladder is exhausted — otherwise one notch would skip a rung.
	if main.reflections.mode >= 2:
		main.reflections.apply(main.reflections.mode - 1)
		return
	# The sky (cloud deck + aurora, both multi-octave fbm, full-screen, every
	# frame) was never gated by anything above and turned out to be the real
	# fixed-cost bottleneck on real hardware — shed it before the small stuff.
	if not _sky_cheap:
		_sky_cheap = true
		main.sky_mat.set_shader_parameter("sky_cheap", true)
		return
	tier += 1
	match tier:
		1:
			main.moon.shadow_enabled = false
		2:
			main.conductor.set_sparkle_level(0)
		3:
			get_viewport().msaa_3d = Viewport.MSAA_2X
		_:
			_exhausted = true
