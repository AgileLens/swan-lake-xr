shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Spectral bands across the bow, faded at both ends and painted in by bearing bins.
uniform float alpha = 0.0;
uniform float bins[14];

vec3 spectrum(float v) {
	// Violet inside, red outside, as in a primary bow.
	vec3 c = vec3(0.0);
	c += vec3(0.42, 0.14, 0.72) * smoothstep(0.0, 0.14, v) * (1.0 - smoothstep(0.14, 0.32, v));
	c += vec3(0.10, 0.25, 0.85) * smoothstep(0.12, 0.28, v) * (1.0 - smoothstep(0.28, 0.46, v));
	c += vec3(0.10, 0.70, 0.30) * smoothstep(0.28, 0.46, v) * (1.0 - smoothstep(0.46, 0.62, v));
	c += vec3(0.95, 0.82, 0.12) * smoothstep(0.44, 0.60, v) * (1.0 - smoothstep(0.60, 0.74, v));
	c += vec3(0.95, 0.42, 0.08) * smoothstep(0.58, 0.72, v) * (1.0 - smoothstep(0.72, 0.86, v));
	c += vec3(0.90, 0.10, 0.08) * smoothstep(0.70, 0.84, v) * (1.0 - smoothstep(0.88, 1.0, v));
	return c;
}

void fragment() {
	float x = UV.x * 13.0;
	int i = int(floor(x));
	float b = mix(bins[clamp(i, 0, 13)], bins[clamp(i + 1, 0, 13)], smoothstep(0.0, 1.0, fract(x)));
	float ends = smoothstep(0.0, 0.14, UV.x) * (1.0 - smoothstep(0.86, 1.0, UV.x));
	ALBEDO = spectrum(UV.y) * alpha * b * ends * 0.55;
}
