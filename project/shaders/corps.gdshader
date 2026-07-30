shader_type spatial;
// Corps de ballet swans: white PBR + per-instance bob/roll in the vertex shader.
// INSTANCE_CUSTOM.x = phase, .y = rate (set from MegaFlock).

uniform float u_time = 0.0;

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float rate = INSTANCE_CUSTOM.y;
	float bob = sin(u_time * 0.9 * rate + phase) * 0.025;
	float roll = sin(u_time * 0.7 * rate + phase * 1.7) * 0.02;
	VERTEX.y += bob + VERTEX.x * roll;
}

void fragment() {
	ALBEDO = vec3(0.93, 0.93, 0.91);
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
}
