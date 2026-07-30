shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.010, 0.025, 0.050);
uniform vec3 horizon_color : source_color = vec3(0.05, 0.09, 0.16);
uniform vec3 glint_color : source_color = vec3(0.85, 0.92, 1.0);
uniform vec3 moon_dir = vec3(-0.22, 0.28, -0.93);
uniform float glint_strength = 1.1;
uniform float glint_pulse = 0.0;        // fireworks flash
uniform float u_time = 0.0;
uniform float music_energy = 0.0;
uniform float wave_amp = 1.0;           // weather boost
uniform float star_sparkle = 1.0;       // twinkling star glitter on calm water
uniform float water_metallic = 0.0;     // raised in Probe reflection mode
uniform int refl_mode = 0;              // 0 analytic, 1 probe, 2 planar mono, 3 planar stereo
uniform sampler2D planar_tex : source_color, hint_default_black;
uniform mat4 refl_vp;
// Mode 3 renders a second mirrored camera from the right eye. In mono planar both
// eyes sample one viewpoint, so reflected objects sit at the wrong disparity and
// the water reads as a flat pasted image rather than a surface with depth.
uniform sampler2D planar_tex_r : source_color, hint_default_black;
uniform mat4 refl_vp_r;
uniform vec4 u_ripples[28];  // xy world xz, z birth, w strength
uniform vec4 u_ripples2[28]; // freq, speed, life, sharpness

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(v_world.x * 0.5 + u_time * 0.7) * 0.02
			   + cos(v_world.z * 0.4 + u_time * 0.55) * 0.02) * wave_amp;
}

vec3 ripple_field(vec2 p) {
	float h = 0.0;
	vec2 grad = vec2(0.0);
	for (int i = 0; i < 28; i++) {
		vec4 r = u_ripples[i];
		if (r.w <= 0.001) { continue; }
		float age = u_time - r.z;
		vec4 q = u_ripples2[i];
		if (age < 0.0 || age > q.z) { continue; }
		vec2 to_p = p - r.xy;
		float d = length(to_p) + 0.0001;
		float front = age * q.y;
		float phase = (d - front) * q.x;
		float atten = exp(-abs(d - front) * 1.8 * q.w) * exp(-age * (4.8 / q.z))
					* smoothstep(0.0, 0.2, age) * r.w;
		h += sin(phase) * atten;
		grad += (to_p / d) * cos(phase) * q.x * atten;
	}
	return vec3(h, grad);
}

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 p = v_world.xz;
	float nx = (cos(p.x * 1.7 + u_time * 0.9) * 0.102
			  + cos((p.x * 0.6 + p.y * 0.8) * 2.3 + u_time * 1.4) * 0.041
			  + cos(p.x * 5.1 + p.y * 1.3 + u_time * 2.2) * 0.012) * wave_amp;
	float nz = (cos(p.y * 1.3 + u_time * 0.7) * 0.078
			  + cos((p.x * 0.6 + p.y * 0.8) * 2.3 + u_time * 1.4) * 0.055
			  + cos(p.y * 4.3 - p.x * 1.1 + u_time * 1.9) * 0.012) * wave_amp;
	vec3 rip = ripple_field(p);
	nx += rip.y * 0.030;
	nz += rip.z * 0.030;
	vec3 n = normalize(vec3(-nx, 1.0, -nz));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 vdir = normalize(v_world - CAMERA_POSITION_WORLD);
	float fres = pow(1.0 - clamp(dot(n, -vdir), 0.0, 1.0), 3.0);
	ALBEDO = mix(base_color, horizon_color, fres);
	ROUGHNESS = 0.10;
	METALLIC = water_metallic;
	SPECULAR = 0.55;
	vec3 refl = reflect(vdir, n);
	float md = max(dot(refl, normalize(moon_dir)), 0.0);
	float streak = pow(md, 600.0) * 2.4 + pow(md, 48.0) * 0.10;
	vec3 emis = glint_color * streak * (glint_strength + music_energy * 0.9 + glint_pulse);
	// star glitter: tiny transient sparks on calm facets, densest away from the moon streak
	float calm = 1.0 - clamp(abs(nx) * 14.0 + abs(nz) * 14.0, 0.0, 1.0);
	vec2 cell = floor(p * 7.0);
	float hsh = hash21(cell + floor(u_time * vec2(1.7, 1.3)));
	float spark = step(0.985, hsh) * calm * star_sparkle * (0.5 + 0.5 * sin(u_time * 9.0 + hsh * 40.0));
	emis += vec3(0.8, 0.9, 1.0) * spark * 0.35 * fres;
	// planar reflection: mirrored camera(s), UVs perturbed by the wave normal
	if (refl_mode >= 2) {
		bool right = (refl_mode == 3 && VIEW_INDEX == VIEW_RIGHT);
		mat4 vp = right ? refl_vp_r : refl_vp;
		vec4 rp = vp * vec4(v_world, 1.0);
		if (rp.w > 0.0) {
			vec2 ruv = rp.xy / rp.w * 0.5 + 0.5;
			ruv += vec2(nx, nz) * 0.12;
			if (ruv.x > 0.0 && ruv.x < 1.0 && ruv.y > 0.0 && ruv.y < 1.0) {
				vec2 fuv = vec2(ruv.x, 1.0 - ruv.y);
				vec3 pc = right ? texture(planar_tex_r, fuv).rgb : texture(planar_tex, fuv).rgb;
				emis += pc * fres * 0.45;
			}
		}
	}
	EMISSION = emis + mix(base_color, horizon_color, 0.5) * rip.x * 0.5;
}
