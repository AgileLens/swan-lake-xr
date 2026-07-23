shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.010, 0.025, 0.050);
uniform vec3 horizon_color : source_color = vec3(0.05, 0.09, 0.16);
uniform vec3 glint_color : source_color = vec3(0.85, 0.92, 1.0);
uniform vec3 moon_dir = vec3(-0.35, 0.28, -0.89);
uniform float glint_strength = 1.1;
uniform float u_time = 0.0;
uniform float music_energy = 0.0;
uniform vec4 u_ripples[16]; // xy = world xz, z = birth time, w = strength

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(v_world.x * 0.5 + u_time * 0.7) * 0.02
			  + cos(v_world.z * 0.4 + u_time * 0.55) * 0.02;
}

// height + analytic gradient of active ripple rings
vec3 ripple_field(vec2 p) {
	float h = 0.0;
	vec2 grad = vec2(0.0);
	for (int i = 0; i < 16; i++) {
		vec4 r = u_ripples[i];
		if (r.w <= 0.001) { continue; }
		float age = u_time - r.z;
		if (age < 0.0 || age > 6.0) { continue; }
		vec2 to_p = p - r.xy;
		float d = length(to_p) + 0.0001;
		float front = age * 1.6;
		float phase = (d - front) * 12.0;
		float atten = exp(-abs(d - front) * 1.8) * exp(-age * 0.8) * smoothstep(0.0, 0.2, age) * r.w;
		h += sin(phase) * atten;
		grad += (to_p / d) * cos(phase) * 12.0 * atten;
	}
	return vec3(h, grad);
}

void fragment() {
	vec2 p = v_world.xz;
	// layered trig wavelets (analytic normals, no textures)
	float nx = cos(p.x * 1.7 + u_time * 0.9) * 0.102
			 + cos((p.x * 0.6 + p.y * 0.8) * 2.3 + u_time * 1.4) * 0.041
			 + cos(p.x * 5.1 + p.y * 1.3 + u_time * 2.2) * 0.012;
	float nz = cos(p.y * 1.3 + u_time * 0.7) * 0.078
			 + cos((p.x * 0.6 + p.y * 0.8) * 2.3 + u_time * 1.4) * 0.055
			 + cos(p.y * 4.3 - p.x * 1.1 + u_time * 1.9) * 0.012;
	vec3 rip = ripple_field(p);
	nx += rip.y * 0.030;
	nz += rip.z * 0.030;
	vec3 n = normalize(vec3(-nx, 1.0, -nz));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 vdir = normalize(v_world - CAMERA_POSITION_WORLD);
	float fres = pow(1.0 - clamp(dot(n, -vdir), 0.0, 1.0), 3.0);
	ALBEDO = mix(base_color, horizon_color, fres);
	ROUGHNESS = 0.10;
	METALLIC = 0.0;
	SPECULAR = 0.55;
	vec3 refl = reflect(vdir, n);
	float md = max(dot(refl, normalize(moon_dir)), 0.0);
	float streak = pow(md, 600.0) * 2.4 + pow(md, 48.0) * 0.10;
	EMISSION = glint_color * streak * (glint_strength + music_energy * 0.9);
	EMISSION += mix(base_color, horizon_color, 0.5) * rip.x * 0.5;
}
