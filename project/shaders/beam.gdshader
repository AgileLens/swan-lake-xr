shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.55, 0.75, 1.0);
uniform float alpha = 0.0;
// Beam volume in world space, set from SwanLakeMain._place_beam().
uniform vec3 beam_base = vec3(0.0);   // where the shaft meets the water
uniform vec3 beam_axis = vec3(0.0, 1.0, 0.0);
uniform float beam_radius = 0.75;

varying float v_h; // 0 bottom .. 1 top of cylinder
varying vec3 v_world;

void vertex() {
	v_h = clamp(VERTEX.y / 10.0 + 0.5, 0.0, 1.0);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fade = smoothstep(0.0, 0.25, v_h) * (1.0 - smoothstep(0.55, 1.0, v_h));
	// Softness comes from how much beam volume the view ray crosses, approximated
	// by the chord of a circle of beam_radius: full brightness through the axis,
	// smoothly to zero at the rim.
	//
	// The previous version feathered on abs(dot(NORMAL, VIEW)) instead. On a
	// cylinder that term falls off within a couple of pixels of the silhouette
	// (the surface turns away almost instantly), so the shaft got a crisp outline
	// and read as a solid object rather than light — what Alex saw in the headset
	// and described as inverted normals.
	vec3 v = normalize(v_world - CAMERA_POSITION_WORLD);
	vec3 a = normalize(beam_axis);
	vec3 n = cross(v, a);
	float sl = length(n);
	float dist;
	if (sl < 1e-4) {
		// looking straight down the shaft: fall back to radial distance
		dist = length(cross(v_world - beam_base, a));
	} else {
		dist = abs(dot(CAMERA_POSITION_WORLD - beam_base, n / sl));
	}
	float x = clamp(dist / beam_radius, 0.0, 1.0);
	float chord = sqrt(max(0.0, 1.0 - x * x));
	ALBEDO = tint;
	// 0.5 because cull_disabled draws both walls and this blends additively
	ALPHA = alpha * fade * chord * 0.5;
}
