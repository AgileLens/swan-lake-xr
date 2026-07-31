shader_type spatial;
// Corps de ballet swans. Two behaviors blended by `chorus`:
//
//   audience (chorus = 0) — they've come to watch. Facing the dock, holding
//     mostly still, just breathing on the water.
//   chorus  (chorus = 1) — they join in: swaying on the beat and lifting their
//     wings, with the movement travelling outward from the stage as a wave so
//     the crowd moves like a crowd rather than a metronome.
//
// INSTANCE_CUSTOM: x = phase, y = rate, z = wave delay (0 near .. 1 far),
//                  w = per-instance sway scale.

uniform float u_time = 0.0;
uniform float beat_phase = 0.0;   // 0..1 across a quarter note
uniform float bar_phase = 0.0;    // 0..1 across four beats
uniform float chorus = 0.0;       // 0 audience .. 1 full chorus
uniform float music_energy = 0.0;
// The baked swan is only ±0.25 units wide (measured from the mesh AABB, not
// guessed) — a 0.22 threshold left 0.03 units of "wing" and the flap was
// invisible. Hinge at 0.09 so the outer ~2/3 of the wing actually travels.
uniform float wing_hinge = 0.09;
uniform float wing_tip = 0.25;

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float rate = INSTANCE_CUSTOM.y;
	float wave = INSTANCE_CUSTOM.z;
	float amp = INSTANCE_CUSTOM.w;

	// idle: always present, so even a still audience is alive on the water
	float bob = sin(u_time * 0.9 * rate + phase) * 0.025;
	float roll = sin(u_time * 0.7 * rate + phase * 1.7) * 0.02;

	if (chorus > 0.001) {
		// the beat reaches the far ranks later — a wave through the crowd
		float bp = fract(beat_phase - wave * 0.35);
		float barp = fract(bar_phase - wave * 0.35);
		// sway: lean side to side, peaking on the beat
		float sway = sin(bp * 6.28318) * amp * chorus;
		roll += sway * 0.26;
		// rise onto the beat — the whole body lifts
		bob += (1.0 - abs(bp * 2.0 - 1.0)) * 0.09 * chorus * (0.6 + music_energy);
		// wings: up on the first half of the bar, settling on the second. The mesh
		// is baked so there are no bones, but the wings are the laterally-extreme
		// vertices — hinging them about the body axis reads as a real wing beat
		// across thousands of instances for the cost of a smoothstep.
		float lift = sin(barp * 3.14159);
		lift = lift * lift;
		float wingf = smoothstep(wing_hinge, wing_tip, abs(VERTEX.x));
		VERTEX.y += abs(VERTEX.x) * wingf * lift * 1.6 * chorus;
		// tips draw in and trail as they rise, like a real wing folding upward
		VERTEX.x -= VERTEX.x * wingf * lift * 0.25 * chorus;
		VERTEX.z -= wingf * lift * 0.10 * chorus;
	}
	VERTEX.y += bob + VERTEX.x * roll;
}

void fragment() {
	ALBEDO = vec3(0.93, 0.93, 0.91);
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
}
