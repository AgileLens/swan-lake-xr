class_name MoodKit
extends Node
# Night / Dusk / Dawn palettes: sky, water, fog, moon, fireflies, sparkle accent,
# firework colors, milky way. A/X (or 1/2/3 desktop) cycles, everything tweens.

var main  # SwanLakeMain (untyped: cyclic)
var order := ["night", "dusk", "dawn"]
var current := "night"

var presets := {
	"night": {
		"cloud_cover": 0.42,
		"cloud_tint": Color(0.34, 0.42, 0.60),
		"aurora": 0.55,
		"aurora_a": Color(0.16, 0.92, 0.60),
		"aurora_b": Color(0.45, 0.35, 0.95),
		"sky_top": Color(0.010, 0.015, 0.045),
		"sky_horizon": Color(0.050, 0.080, 0.160),
		"stars": 1.0,
		"milkyway": 1.0,
		"moon_color": Color(0.98, 0.97, 0.90),
		"moon_energy": 0.35,
		"moon_dir": Vector3(-0.22, 0.28, -0.93),
		"fog_color": Color(0.020, 0.040, 0.070),
		"fog_density": 0.012,
		"water_base": Color(0.010, 0.025, 0.050),
		"water_horizon": Color(0.050, 0.090, 0.160),
		"glint": Color(0.85, 0.92, 1.00),
		"firefly": Color(0.55, 0.85, 1.00),
		"accent": Color(0.80, 0.95, 1.00),
		"beam": Color(0.55, 0.75, 1.00),
		"fireworks": [Color(0.65, 0.85, 1.0), Color(0.95, 0.97, 1.0), Color(0.75, 0.6, 1.0)],
	},
	"dusk": {
		"cloud_cover": 0.58,
		"cloud_tint": Color(0.62, 0.42, 0.48),
		"aurora": 0.0,
		"aurora_a": Color(0.60, 0.40, 0.80),
		"aurora_b": Color(0.90, 0.50, 0.55),
		"sky_top": Color(0.055, 0.030, 0.100),
		"sky_horizon": Color(0.480, 0.190, 0.150),
		"stars": 0.35,
		"milkyway": 0.30,
		"moon_color": Color(1.00, 0.84, 0.62),
		"moon_energy": 0.30,
		"moon_dir": Vector3(-0.30, 0.16, -0.94),
		"fog_color": Color(0.140, 0.070, 0.080),
		"fog_density": 0.010,
		"water_base": Color(0.022, 0.014, 0.038),
		"water_horizon": Color(0.330, 0.140, 0.130),
		"glint": Color(1.00, 0.72, 0.45),
		"firefly": Color(1.00, 0.75, 0.40),
		"accent": Color(1.00, 0.72, 0.45),
		"beam": Color(1.00, 0.70, 0.45),
		"fireworks": [Color(1.0, 0.78, 0.35), Color(1.0, 0.5, 0.45), Color(0.95, 0.5, 0.9)],
	},
	"dawn": {
		"cloud_cover": 0.50,
		"cloud_tint": Color(0.78, 0.68, 0.66),
		"aurora": 0.0,
		"aurora_a": Color(0.50, 0.80, 0.90),
		"aurora_b": Color(0.95, 0.75, 0.60),
		"sky_top": Color(0.140, 0.200, 0.360),
		"sky_horizon": Color(0.780, 0.580, 0.480),
		"stars": 0.0,
		"milkyway": 0.0,
		"moon_color": Color(1.00, 0.96, 0.88),
		"moon_energy": 0.55,
		"moon_dir": Vector3(-0.15, 0.42, -0.90),
		"fog_color": Color(0.420, 0.400, 0.420),
		"fog_density": 0.009,
		"water_base": Color(0.050, 0.068, 0.100),
		"water_horizon": Color(0.480, 0.400, 0.380),
		"glint": Color(1.00, 0.92, 0.75),
		"firefly": Color(1.00, 0.95, 0.80),
		"accent": Color(1.00, 0.90, 0.70),
		"beam": Color(0.85, 0.90, 1.00),
		"fireworks": [Color(1.0, 0.85, 0.6), Color(1.0, 0.6, 0.6), Color(0.95, 0.9, 0.75)],
	},
}

func setup(m) -> void:
	main = m

func cycle() -> void:
	var i := (order.find(current) + 1) % order.size()
	apply(order[i], false)

func apply(name: String, instant: bool) -> void:
	current = name
	var p: Dictionary = presets[name]
	var dur := 0.0 if instant else 2.2
	_sh(main.sky_mat, "top_color", p.sky_top, dur)
	_sh(main.sky_mat, "horizon_color", p.sky_horizon, dur)
	_sh(main.sky_mat, "star_intensity", p.stars, dur)
	_sh(main.sky_mat, "milkyway_intensity", p.milkyway, dur)
	_sh(main.sky_mat, "moon_color", p.moon_color, dur)
	_sh(main.sky_mat, "cloud_cover", p.cloud_cover, dur)
	_sh(main.sky_mat, "cloud_tint", p.cloud_tint, dur)
	_sh(main.sky_mat, "aurora_intensity", p.aurora, dur)
	_sh(main.sky_mat, "aurora_a", p.aurora_a, dur)
	_sh(main.sky_mat, "aurora_b", p.aurora_b, dur)
	_sh(main.water_mat, "base_color", p.water_base, dur)
	_sh(main.water_mat, "horizon_color", p.water_horizon, dur)
	_sh(main.water_mat, "glint_color", p.glint, dur)
	_sh(main.beam_mat, "tint", p.beam, dur)
	main.fireflies.set_mood_colors(p.firefly, p.accent)
	main.conductor.set_accent(p.accent)
	main.fireworks.set_palette(p.fireworks)
	if instant:
		main.env.fog_light_color = p.fog_color
		main.env.fog_density = p.fog_density
		main.moon.light_color = p.moon_color
		main.moon.light_energy = p.moon_energy
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(main.env, "fog_light_color", p.fog_color, dur)
		tw.tween_property(main.env, "fog_density", p.fog_density, dur)
		tw.tween_property(main.moon, "light_color", p.moon_color, dur)
		tw.tween_property(main.moon, "light_energy", p.moon_energy, dur)
	main._aim_moon(p.moon_dir)

func _sh(mat: ShaderMaterial, uniform: String, to_val, dur: float) -> void:
	if dur <= 0.0:
		mat.set_shader_parameter(uniform, to_val)
		return
	var from_val = mat.get_shader_parameter(uniform)
	var tw := create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter(uniform, v), from_val, to_val, dur)
