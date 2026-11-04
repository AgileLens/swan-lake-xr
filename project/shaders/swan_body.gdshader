shader_type spatial;
// The hero swan's skin: baked atlas (paint x occlusion) and a baked plumage normal map.
// White birds read as balloons when shading is flat, so the form comes from the baked
// occlusion, a feather normal map, and a soft fuzz at grazing angles instead of plastic
// specular. Bill and eye are told apart by color and get a tighter highlight.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float normal_depth = 0.8;
uniform float fuzz = 0.42;
uniform vec3 waterline_tint : source_color = vec3(0.55, 0.62, 0.70);
uniform float exposure = 1.0;
varying float v_world_y;

void vertex() {
	v_world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float dark = 1.0 - smoothstep(0.03, 0.22, max(c.r, max(c.g, c.b)));
	float gloss = clamp(sat * 2.4 + dark, 0.0, 1.0);
	// Lit from the water below: a slight cool lift at the waterline, then contact shade.
	float wl = smoothstep(0.10, 0.0, v_world_y);
	c = mix(c, c * waterline_tint, wl * 0.7);
	ALBEDO = c * exposure;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = mix(0.82, 0.30, gloss);
	SPECULAR = mix(0.18, 0.5, gloss);
	RIM = fuzz * (1.0 - gloss);
	RIM_TINT = 0.75;
	BACKLIGHT = vec3(0.22) * (1.0 - gloss);
}
