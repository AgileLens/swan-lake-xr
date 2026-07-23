shader_type sky;

uniform vec3 top_color : source_color = vec3(0.010, 0.015, 0.045);
uniform vec3 horizon_color : source_color = vec3(0.05, 0.08, 0.16);
uniform vec3 moon_color : source_color = vec3(1.0, 0.98, 0.90);
uniform vec3 moon_dir = vec3(-0.35, 0.28, -0.89);
uniform float moon_size = 0.035;
uniform float star_intensity = 1.0;
uniform float u_time = 0.0;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	float t = clamp(d.y * 1.5 + 0.22, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(t, 0.65));
	// stars on a direction grid, twinkling
	if (d.y > 0.015) {
		vec3 dd = d * 170.0;
		vec3 cell = floor(dd);
		float h = hash3(cell);
		if (h > 0.994) {
			float sd = length(dd - cell - 0.5);
			float tw = 0.7 + 0.3 * sin(u_time * (1.0 + h * 5.0) + h * 44.0);
			col += vec3(0.9, 0.95, 1.0) * smoothstep(0.55, 0.05, sd)
				 * star_intensity * tw * smoothstep(0.015, 0.18, d.y);
		}
	}
	// moon disc + halo
	float ang = acos(clamp(dot(d, normalize(moon_dir)), -1.0, 1.0));
	float disc = smoothstep(moon_size, moon_size * 0.7, ang);
	float glow = exp(-ang * 8.0) * 0.32 + exp(-ang * 2.2) * 0.07;
	col += moon_color * (disc * 1.7 + glow);
	// faint band of mist near horizon
	col += horizon_color * exp(-abs(d.y) * 14.0) * 0.35;
	COLOR = col;
}
