shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, particle_trails;
// Fireflies were sharing snow's exact visual language (small pale radial-glow
// dot, billboarded) — Alex: "snow should look different from fireflies, and
// fireflies should have a pulsing yellow glow and turn on and off, in time to
// the music." Each firefly blinks on its own phase (derived from INSTANCE_ID,
// not a shared clock, so the swarm doesn't flash in unison) but the whole
// swarm's blink RATE locks to the beat, so it still reads as musical.

uniform sampler2D albedo_tex : source_color, hint_default_black;
uniform vec3 warm_color : source_color = vec3(1.0, 0.72, 0.18);
uniform vec3 accent_color : source_color = vec3(1.0, 0.75, 0.9);
uniform float accent_mix = 0.0;      // 0 = pure warm firefly color, 1 = mood accent
uniform float drive = 0.0;           // conducting/music energy, brightens + speeds blink
uniform float beat_phase = 0.0;      // 0..1 across one quarter note
uniform float proximity_fade_distance = 0.35;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying float v_seed;

float hash11(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void vertex() {
	// stable per-particle random in [0,1), independent of any shared clock —
	// this is what keeps individual fireflies from blinking in lockstep
	v_seed = hash11(float(INSTANCE_ID) + 11.0);
	// Full spherical billboard: there's no `billboard` render_mode for a raw
	// spatial shader (that's only a BaseMaterial3D convenience) — rebuild
	// MODELVIEW_MATRIX to face the camera directly while keeping world
	// position, the standard Godot 4 billboard technique.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
}

void fragment() {
	// Blink envelope: mostly OFF, brief bright pulses — an insect flicker, not
	// a smooth breathing glow (which is what made it read as "just a dot").
	// Rate is beat-locked (all fireflies share the same period) but each one's
	// phase within that period is offset by its own seed, and drive stretches
	// how much of the cycle stays lit as the music/conducting intensifies.
	float phase = fract(beat_phase + v_seed);
	float duty = mix(0.12, 0.42, clamp(drive, 0.0, 1.0));
	float blink = smoothstep(duty, duty * 0.55, phase) + smoothstep(1.0 - duty * 0.3, 1.0, phase);
	// a faint idle glow so a firefly is still findable between pulses, not
	// truly invisible — reads as "dim, then flares," not "on/off strobing"
	blink = clamp(blink + 0.10, 0.0, 1.0);

	vec4 tex = texture(albedo_tex, UV);
	vec3 col = mix(warm_color, accent_color, clamp(accent_mix, 0.0, 1.0));
	ALBEDO = col;
	EMISSION = col * (1.4 + drive * 3.2) * blink;
	ALPHA = tex.a * (0.25 + blink * 0.65);

	// soft-particle depth fade (StandardMaterial3D's proximity_fade, done by
	// hand since this is now a custom shader) — a firefly drifting into a swan
	// or the dock blends out instead of z-fighting as a hard sprite edge
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	float scene_z = -(upos.xyz / upos.w).z;
	float part_z = -VERTEX.z;
	float fade = clamp((scene_z - part_z) / max(proximity_fade_distance, 0.001), 0.0, 1.0);
	ALPHA *= fade;
}
