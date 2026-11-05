shader_type spatial;
render_mode cull_back;
// Reed cards carry explicit front and back triangles in env.glb. They remain visibly two-sided
// without disabling culling, so an accidental reversed face cannot be hidden by the material.
uniform float u_time_scale = 1.0;
uniform float wind = 1.0;
uniform float night_fill = 0.0;
varying float v_emit;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = w.x * 0.9 + w.z * 0.7;
	float sway = sin(TIME * 1.5 + phase) + 0.5 * sin(TIME * 2.9 + phase * 1.7);
	VERTEX.x += sway * 0.028 * wind * COLOR.a;
	VERTEX.z += cos(TIME * 1.1 + phase) * 0.018 * wind * COLOR.a;
	v_emit = UV.x;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
	EMISSION = COLOR.rgb * (v_emit * 6.0 + night_fill);
}
