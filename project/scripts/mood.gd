class_name MoodKit
extends Node
# Night / Dusk / Dawn palettes: sky, water, fog, moon, fireflies, sparkle accent,
# firework colors, milky way. A/X (or 1/2/3 desktop) cycles, everything tweens.

var main  # SwanLakeMain (untyped: cyclic)
var order := ["night", "dusk", "dawn", "morning", "golden"]
var sun_nudge := 0.0   # 0..1: the raised baton lifts the sun a little in the Dawn movement
var _base_sun := Vector3.ZERO
var _star_amount := 1.0
var _live: Array[Tween] = []
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
		"ambient": 1.05, "reflect": 0.42, "fill": 0.16,
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
		"ambient": 0.9, "reflect": 0.42, "fill": 0.10,
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
	"predawn": {
		"cloud_cover": 0.30, "cloud_tint": Color(0.20, 0.24, 0.36), "aurora": 0.0,
		"aurora_a": Color(0.16, 0.92, 0.60), "aurora_b": Color(0.45, 0.35, 0.95),
		"sky_top": Color(0.012, 0.022, 0.070), "sky_horizon": Color(0.150, 0.150, 0.270),
		"stars": 0.85, "milkyway": 0.7, "moon_color": Color(0.85, 0.90, 1.00), "moon_energy": 0.14,
		"moon_dir": Vector3(0.45, 0.45, -0.77), "fog_color": Color(0.060, 0.070, 0.120), "fog_density": 0.016,
		"water_base": Color(0.012, 0.022, 0.050), "water_horizon": Color(0.110, 0.120, 0.210),
		"glint": Color(0.70, 0.78, 1.00), "firefly": Color(0.55, 0.85, 1.00), "accent": Color(0.75, 0.82, 1.00),
		"beam": Color(0.55, 0.75, 1.00), "fireworks": [Color(0.65, 0.85, 1.0), Color(0.95, 0.97, 1.0), Color(0.75, 0.6, 1.0)],
		"ambient": 0.75, "sun": 0.0, "reflect": 0.45, "fill": 0.14,
	},
	"sunrise": {
		"cloud_cover": 0.42, "cloud_tint": Color(1.00, 0.70, 0.56), "aurora": 0.0,
		"aurora_a": Color(0.50, 0.80, 0.90), "aurora_b": Color(0.95, 0.75, 0.60),
		"sky_top": Color(0.150, 0.280, 0.520), "sky_horizon": Color(1.00, 0.640, 0.420),
		"stars": 0.0, "milkyway": 0.0, "moon_color": Color(1.00, 0.76, 0.50), "moon_energy": 1.05,
		"moon_dir": Vector3(-0.58, 0.20, -0.79), "fog_color": Color(0.780, 0.580, 0.470), "fog_density": 0.0034,
		"water_base": Color(0.030, 0.050, 0.080), "water_horizon": Color(0.320, 0.240, 0.200),
		"glint": Color(1.00, 0.80, 0.55), "firefly": Color(1.00, 0.95, 0.80), "accent": Color(1.00, 0.85, 0.60),
		"beam": Color(1.00, 0.85, 0.65), "fireworks": [Color(1.0, 0.85, 0.6), Color(1.0, 0.6, 0.6), Color(0.95, 0.9, 0.75)],
		"ambient": 0.75, "sun": 1.0, "reflect": 0.40, "swan": 0.92,
	},
	"morning": {
		"cloud_cover": 0.36, "cloud_tint": Color(1.00, 0.99, 0.97), "aurora": 0.0,
		"aurora_a": Color(0.50, 0.80, 0.90), "aurora_b": Color(0.95, 0.75, 0.60),
		"sky_top": Color(0.150, 0.330, 0.700), "sky_horizon": Color(0.700, 0.830, 0.930),
		"stars": 0.0, "milkyway": 0.0, "moon_color": Color(1.00, 0.96, 0.88), "moon_energy": 1.25,
		"moon_dir": Vector3(-0.46, 0.66, -0.60), "fog_color": Color(0.660, 0.780, 0.880), "fog_density": 0.0030,
		"water_base": Color(0.014, 0.075, 0.110), "water_horizon": Color(0.140, 0.300, 0.400),
		"glint": Color(1.00, 0.97, 0.88), "firefly": Color(1.00, 0.95, 0.80), "accent": Color(1.00, 0.95, 0.75),
		"beam": Color(1.00, 0.95, 0.80), "fireworks": [Color(1.0, 0.85, 0.5), Color(0.9, 0.5, 0.5), Color(0.5, 0.7, 1.0)],
		"ambient": 0.72, "sun": 1.0, "reflect": 0.36, "swan": 0.84,
	},
	"gathering": {
		"cloud_cover": 0.82, "cloud_tint": Color(0.42, 0.46, 0.52), "aurora": 0.0,
		"aurora_a": Color(0.5, 0.8, 0.9), "aurora_b": Color(0.9, 0.7, 0.6),
		"sky_top": Color(0.120, 0.160, 0.240), "sky_horizon": Color(0.420, 0.470, 0.520),
		"stars": 0.0, "milkyway": 0.0, "moon_color": Color(0.88, 0.90, 0.96), "moon_energy": 0.42,
		"moon_dir": Vector3(-0.20, 0.72, -0.66), "fog_color": Color(0.320, 0.370, 0.420), "fog_density": 0.012,
		"water_base": Color(0.030, 0.060, 0.075), "water_horizon": Color(0.300, 0.360, 0.420),
		"glint": Color(0.80, 0.86, 0.92), "firefly": Color(0.8, 0.9, 1.0), "accent": Color(0.75, 0.88, 1.00),
		"beam": Color(0.8, 0.9, 1.0), "fireworks": [Color(0.7, 0.8, 1.0), Color(0.9, 0.9, 1.0), Color(0.7, 0.6, 1.0)],
		"ambient": 0.7, "sun": 0.4, "reflect": 0.5,
	},
	"storm": {
		"cloud_cover": 1.0, "cloud_tint": Color(0.17, 0.19, 0.24), "aurora": 0.0,
		"aurora_a": Color(0.5, 0.8, 0.9), "aurora_b": Color(0.9, 0.7, 0.6),
		"sky_top": Color(0.040, 0.052, 0.075), "sky_horizon": Color(0.150, 0.180, 0.210),
		"stars": 0.0, "milkyway": 0.0, "moon_color": Color(0.70, 0.76, 0.88), "moon_energy": 0.20,
		"moon_dir": Vector3(0.05, 0.80, -0.60), "fog_color": Color(0.110, 0.130, 0.160), "fog_density": 0.024,
		"water_base": Color(0.014, 0.030, 0.038), "water_horizon": Color(0.120, 0.150, 0.180),
		"glint": Color(0.70, 0.78, 0.90), "firefly": Color(0.8, 0.9, 1.0), "accent": Color(0.70, 0.86, 1.00),
		"beam": Color(0.7, 0.85, 1.0), "fireworks": [Color(0.7, 0.8, 1.0), Color(0.9, 0.9, 1.0), Color(0.7, 0.6, 1.0)],
		"ambient": 0.75, "sun": 0.0, "reflect": 0.45,
	},
	"clearing": {
		"cloud_cover": 0.52, "cloud_tint": Color(0.96, 0.92, 0.84), "aurora": 0.0,
		"aurora_a": Color(0.5, 0.8, 0.9), "aurora_b": Color(0.9, 0.7, 0.6),
		"sky_top": Color(0.170, 0.320, 0.600), "sky_horizon": Color(0.760, 0.780, 0.760),
		"stars": 0.0, "milkyway": 0.0, "moon_color": Color(1.00, 0.92, 0.76), "moon_energy": 1.20,
		"moon_dir": Vector3(0.38, 0.50, 0.78), "fog_color": Color(0.680, 0.730, 0.760), "fog_density": 0.0036,
		"water_base": Color(0.014, 0.070, 0.095), "water_horizon": Color(0.160, 0.300, 0.360),
		"glint": Color(1.00, 0.95, 0.80), "firefly": Color(1.00, 0.95, 0.80), "accent": Color(1.00, 0.90, 0.65),
		"beam": Color(1.00, 0.93, 0.75), "fireworks": [Color(1.0, 0.85, 0.5), Color(0.9, 0.5, 0.5), Color(0.5, 0.7, 1.0)],
		"ambient": 0.72, "sun": 1.0, "reflect": 0.36, "swan": 0.84,
	},
	"golden": {
		"cloud_cover": 0.40, "cloud_tint": Color(1.00, 0.72, 0.46), "aurora": 0.0,
		"aurora_a": Color(0.60, 0.40, 0.80), "aurora_b": Color(0.90, 0.50, 0.55),
		"sky_top": Color(0.180, 0.260, 0.480), "sky_horizon": Color(1.00, 0.620, 0.260),
		"stars": 0.0, "milkyway": 0.0, "moon_color": Color(1.00, 0.78, 0.52), "moon_energy": 1.05,
		"moon_dir": Vector3(0.52, 0.17, -0.84), "fog_color": Color(0.780, 0.500, 0.300), "fog_density": 0.0042,
		"water_base": Color(0.030, 0.038, 0.060), "water_horizon": Color(0.340, 0.210, 0.120),
		"glint": Color(1.00, 0.74, 0.38), "firefly": Color(1.00, 0.75, 0.40), "accent": Color(1.00, 0.76, 0.42),
		"beam": Color(1.00, 0.72, 0.42), "fireworks": [Color(1.0, 0.78, 0.35), Color(1.0, 0.5, 0.45), Color(0.95, 0.5, 0.9)],
		"ambient": 0.72, "sun": 1.0, "reflect": 0.42, "swan": 0.92,
	},
	"gala": {
		"cloud_cover": 0.14, "cloud_tint": Color(0.30, 0.36, 0.52), "aurora": 0.40,
		"aurora_a": Color(0.20, 0.80, 0.75), "aurora_b": Color(0.55, 0.30, 0.95),
		"sky_top": Color(0.006, 0.010, 0.036), "sky_horizon": Color(0.030, 0.052, 0.120),
		"stars": 1.15, "milkyway": 1.2, "moon_color": Color(0.98, 0.97, 0.90), "moon_energy": 0.55,
		"moon_dir": Vector3(-0.30, 0.34, -0.89), "fog_color": Color(0.014, 0.028, 0.056), "fog_density": 0.009,
		"water_base": Color(0.008, 0.020, 0.042), "water_horizon": Color(0.040, 0.070, 0.130),
		"glint": Color(0.85, 0.92, 1.00), "firefly": Color(0.55, 0.85, 1.00), "accent": Color(0.85, 0.95, 1.00),
		"beam": Color(0.55, 0.75, 1.00), "fireworks": [Color(1.0, 0.82, 0.4), Color(0.95, 0.97, 1.0), Color(0.95, 0.4, 0.5), Color(0.5, 0.75, 1.0)],
		"ambient": 1.0, "sun": 0.0, "reflect": 0.45, "fill": 0.16,
	},
}

func setup(m) -> void:
	main = m
	_base_sun = presets["night"].moon_dir

func cycle() -> void:
	var i := (order.find(current) + 1) % order.size()
	apply(order[i], false)

func star_visibility() -> float:
	return _star_amount

func apply(name: String, instant: bool, seconds := 2.2) -> void:
	current = name
	# A new mood replaces any transition still in flight. Otherwise a 70 s sunrise keeps
	# overwriting the next movement's sky, frame by frame, until it runs out.
	for tw in _live:
		if tw and tw.is_valid():
			tw.kill()
	_live.clear()
	var p: Dictionary = presets[name]
	var dur := 0.0 if instant else seconds
	_star_amount = float(p.stars)
	_sh(main.sky_mat, "is_sun", float(p.get("sun", 0.0)), dur)
	_sh(main.water_mat, "reflect_gain", float(p.get("reflect", 0.45)), dur)
	# White birds clip first in daylight: hold them back so feather shading survives.
	SwanLook.materials()
	var swan_gain := float(p.get("swan", 1.0))
	_sh(SwanLook.body_mat, "exposure", swan_gain, dur)
	_sh(SwanLook.feather_mat, "exposure", swan_gain, dur)
	_sh(main.water_mat, "star_sparkle", float(p.stars), dur)
	if main.env_mat:
		_sh(main.env_mat, "night_fill", float(p.get("fill", 0.0)), dur)
	if main.env_foliage_mat:
		_sh(main.env_foliage_mat, "night_fill", float(p.get("fill", 0.0)), dur)
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
		main.env.ambient_light_energy = float(p.get("ambient", 0.7))
		_base_sun = p.moon_dir
		main._aim_moon(p.moon_dir)
		return
	else:
		var tw := create_tween().set_parallel(true)
		_live.append(tw)
		tw.tween_property(main.env, "fog_light_color", p.fog_color, dur)
		tw.tween_property(main.env, "fog_density", p.fog_density, dur)
		tw.tween_property(main.moon, "light_color", p.moon_color, dur)
		tw.tween_property(main.moon, "light_energy", p.moon_energy, dur)
		tw.tween_property(main.env, "ambient_light_energy", float(p.get("ambient", 0.7)), dur)
		# The sun and moon travel, rather than jump, between presets.
		tw.tween_method(_aim_with_nudge, _base_sun, p.moon_dir as Vector3, dur)
	_base_sun = p.moon_dir

func _aim_with_nudge(d: Vector3) -> void:
	main._aim_moon(d + Vector3(0, 0.05 * sun_nudge, 0))

func _sh(mat: ShaderMaterial, uniform: String, to_val, dur: float) -> void:
	if dur <= 0.0:
		mat.set_shader_parameter(uniform, to_val)
		return
	var from_val = mat.get_shader_parameter(uniform)
	if from_val == null:
		mat.set_shader_parameter(uniform, to_val)
		return
	var tw := create_tween()
	_live.append(tw)
	tw.tween_method(func(v): mat.set_shader_parameter(uniform, v), from_val, to_val, dur)
