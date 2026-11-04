shader_type spatial;
render_mode cull_back, depth_draw_always;
// A tailcoat sleeve that dissolves toward the elbow. Top of the cylinder (UV.y = 0) is the cuff end.
void fragment() {
	ALBEDO = vec3(0.045, 0.045, 0.055);
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
	RIM = 0.5;
	RIM_TINT = 0.4;
	ALPHA = 1.0 - smoothstep(0.25, 0.92, UV.y);
}
