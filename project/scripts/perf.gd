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
			hud.text = "fps %d | tier %d | refl %s" % [int(avg), tier, main.reflections.mode_name()]
		if grace <= 0.0 and avg < 71.0:
			_step_down()
			samples.clear()

func _step_down() -> void:
	tier += 1
	match tier:
		1:
			if main.reflections.mode == 2:
				main.reflections.apply(1)
			else:
				tier += 1
			if tier == 2 and main.moon.shadow_enabled:
				main.moon.shadow_enabled = false
		2:
			main.moon.shadow_enabled = false
		3:
			main.conductor.set_sparkle_level(0)
			main.fireflies.particles.amount = 80
		4:
			get_viewport().msaa_3d = Viewport.MSAA_2X
		_:
			pass
