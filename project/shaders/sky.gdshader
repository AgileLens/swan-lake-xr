shader_type sky;

uniform vec3 top_color : source_color = vec3(0.010, 0.015, 0.045);
uniform vec3 horizon_color : source_color = vec3(0.05, 0.08, 0.16);
uniform vec3 moon_color : source_color = vec3(1.0, 0.98, 0.90);
uniform vec3 moon_dir = vec3(-0.22, 0.28, -0.93);
uniform float moon_size = 0.035;
uniform float star_intensity = 1.0;
uniform float milkyway_intensity = 1.0;
uniform float u_time = 0.0;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float star_layer(vec3 d, float cells, float thresh, float tw_speed) {
	vec3 dd = d * cells;
	vec3 cell = floor(dd);
	float h = hash3(cell);
	if (h < thresh) { return 0.0; }
	vec3 center = cell + 0.5 + (vec3(hash3(cell + 1.7), hash3(cell + 3.1), hash3(cell + 5.9)) - 0.5) * 0.55;
	float sd = length(dd - center);
	float tw = 0.7 + 0.3 * sin(u_time * (0.8 + h * tw_speed) + h * 40.0);
	return smoothstep(0.5, 0.04, sd) * tw * smoothstep(0.005, 0.12, d.y);
}

void sky() {
	vec3 d = EYEDIR;
	float t = clamp(d.y * 1.6 + 0.25, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(t, 0.7));
	// two star layers, mixed color temperatures
	float s1 = star_layer(d, 190.0, 0.994, 4.0);
	float s2 = star_layer(d, 420.0, 0.9965, 7.0) * 0.45;
	float hcol = hash3(floor(d * 190.0));
	vec3 star_tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.92, 0.78), step(0.72, hcol));
	col += star_tint * (s1 + s2) * star_intensity;
	// milky way: soft tilted band with clumpy streaks
	vec3 band_n = normalize(vec3(0.55, 0.28, 0.55));
	float band_d = abs(dot(d, band_n));
	float band = exp(-band_d * band_d * 34.0);
	float clump = hash3(floor(d * 24.0)) * hash3(floor(d * 61.0 + 7.0));
	col += vec3(0.50, 0.58, 0.80) * band * (0.030 + 0.028 * clump) * milkyway_intensity
		 * smoothstep(0.0, 0.15, d.y);
	// moon disc + halo, light maria texture
	float ang = acos(clamp(dot(d, normalize(moon_dir)), -1.0, 1.0));
	float disc = smoothstep(moon_size, moon_size * 0.72, ang);
	float maria = 1.0 - 0.22 * hash3(floor(d * 300.0)) * disc;
	float glow = exp(-ang * 9.0) * 0.35 + exp(-ang * 2.5) * 0.08;
	col += moon_color * (disc * 1.7 * maria + glow);
	COLOR = col;
}
