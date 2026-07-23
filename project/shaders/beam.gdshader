shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.55, 0.75, 1.0);
uniform float alpha = 0.0;

varying float v_h; // 0 bottom .. 1 top of cylinder

void vertex() {
	v_h = clamp(VERTEX.y / 10.0 + 0.5, 0.0, 1.0);
}

void fragment() {
	float fade = smoothstep(0.0, 0.25, v_h) * (1.0 - smoothstep(0.55, 1.0, v_h));
	// soften silhouette edges so the cylinder never reads as a hard-walled prism
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = smoothstep(0.15, 0.75, facing);
	ALBEDO = tint;
	ALPHA = alpha * fade * rim;
}
