shader_type spatial;
render_mode cull_back, depth_draw_always;
// A tailcoat sleeve that dissolves toward the elbow. Measured along the cylinder's own height
// (0.22 m, top end at the elbow), because a CylinderMesh's UVs don't span the side's full range.
varying float v_along;

void vertex() {
	v_along = 0.5 - VERTEX.y / 0.22;  // 0 at the elbow end, 1 at the cuff
}

void fragment() {
	ALBEDO = vec3(0.045, 0.045, 0.055);
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
	RIM = 0.5;
	RIM_TINT = 0.4;
	ALPHA = smoothstep(0.12, 0.72, v_along);
}
