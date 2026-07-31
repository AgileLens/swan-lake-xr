shader_type sky;

uniform vec3 top_color : source_color = vec3(0.010, 0.015, 0.045);
uniform vec3 horizon_color : source_color = vec3(0.05, 0.08, 0.16);
uniform vec3 moon_color : source_color = vec3(1.0, 0.98, 0.90);
uniform vec3 moon_dir = vec3(-0.22, 0.28, -0.93);
uniform float moon_size = 0.035;
uniform float star_intensity = 1.0;
uniform float milkyway_intensity = 1.0;
uniform float u_time = 0.0;
// Cloud deck + aurora. The sky was a static gradient plus stars — nothing in it
// moved, which is the biggest "tech demo" tell for a night lake.
uniform float cloud_cover = 0.45;      // 0 clear .. 1 overcast
uniform float cloud_speed = 0.012;
uniform vec3 cloud_tint : source_color = vec3(0.42, 0.50, 0.66);
uniform float aurora_intensity = 0.0;  // per mood
uniform vec3 aurora_a : source_color = vec3(0.18, 0.95, 0.55);
uniform vec3 aurora_b : source_color = vec3(0.55, 0.30, 0.95);
uniform float music_energy = 0.0;
// Perf-governable: the aurora alone is up to 7 fbm() calls per pixel (5 octaves
// each = ~35 vnoise evaluations), full-screen, every frame. Never gated by the
// perf governor's original ladder (corps/fireflies/reflections/shadows/sparkles/
// MSAA) — a real gap found via on-device fps that never recovered even after
// every one of those was already at minimum.
uniform bool sky_cheap = false;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x),
			   mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
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
	vec3 mdir = normalize(moon_dir);

	// --- aurora: curtains, drawn under the clouds so the deck can occlude them.
	// This is the single most expensive thing in the shader — cut first.
	if (!sky_cheap && aurora_intensity > 0.001 && d.y > 0.02) {
		// Horizontal direction as the noise coordinate. Using atan(d.x, d.z) here
		// put a hard vertical seam straight ahead of the viewer, where the angle
		// wraps ±π — the normalized direction vector is continuous everywhere and
		// periodic by construction, so the curtains close seamlessly around the sky.
		vec2 hdir = normalize(vec2(d.x, d.z));
		float ay = d.y * 2.6;
		float ribbon = 0.0;
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float yoff = 0.62 + fi * 0.30;
			float wav = fbm(hdir * 2.2 + vec2(u_time * (0.05 + fi * 0.02), fi * 9.0)) - 0.5;
			float dist = abs(ay - yoff - wav * 0.55);
			// vertical streaking is what makes it read as curtains, not fog
			float streak = 0.55 + 0.45 * fbm(hdir * 14.0 + vec2(u_time * 0.07, fi * 4.0));
			// tight falloff: a wide one overlapped the ribbons into a green wash
			ribbon += exp(-dist * dist * 95.0) * streak * (1.0 - fi * 0.22);
		}
		// gate to one region of the sky, so it reads as an aurora you turn to look
		// at rather than a global tint over everything
		float region = smoothstep(0.05, 0.85, fbm(hdir * 0.9 + vec2(3.0, 1.0)));
		vec3 acol = mix(aurora_a, aurora_b, clamp(ay * 0.5 + 0.15, 0.0, 1.0));
		col += acol * ribbon * region * smoothstep(0.02, 0.30, d.y) * aurora_intensity
			 * (0.75 + music_energy * 0.9);
	}

	// --- cloud deck: EYEDIR projected onto a plane overhead, so clouds converge
	// at the horizon like a real deck instead of pasting onto a dome
	if (d.y > 0.015) {
		vec2 cp = d.xz / max(d.y, 0.015) * 0.55;
		cp += vec2(u_time * cloud_speed, u_time * cloud_speed * 0.6);
		float n = fbm(cp);
		// a slower second layer gives parallax between high and low cloud — skip
		// it in cheap mode, it's a second full fbm() call for a subtle effect
		float dens = n;
		if (!sky_cheap) {
			float n2 = fbm(cp * 0.47 + vec2(11.0, 5.0) - u_time * cloud_speed * 0.35);
			dens = n * 0.65 + n2 * 0.35;
		}
		float c = smoothstep(0.62 - cloud_cover * 0.45, 0.86 - cloud_cover * 0.30, dens);
		c *= smoothstep(0.015, 0.16, d.y);
		// silver lining: brighter where the cloud faces the moon
		float ml = pow(clamp(dot(d, mdir) * 0.5 + 0.5, 0.0, 1.0), 3.0);
		vec3 lit = cloud_tint * (0.55 + 1.35 * ml);
		float core = smoothstep(0.55, 0.95, dens);  // dense core keeps some body
		col = mix(col, mix(lit, cloud_tint * 0.35, core * 0.6), clamp(c, 0.0, 1.0) * 0.92);
	}

	// moon disc + halo, light maria texture
	float ang = acos(clamp(dot(d, mdir), -1.0, 1.0));
	float disc = smoothstep(moon_size, moon_size * 0.72, ang);
	float maria = 1.0 - 0.22 * hash3(floor(d * 300.0)) * disc;
	float glow = exp(-ang * 9.0) * 0.35 + exp(-ang * 2.5) * 0.08;
	col += moon_color * (disc * 1.7 * maria + glow);
	col = max(col, vec3(0.0));
	COLOR = col;
}
