shader_type spatial;
render_mode cull_disabled, shadows_disabled;
// Shadows off for receiving: layers a centimeter apart would shadow each other in a depth map at
// this resolution, and read as a gray wing on a sunlit bird. Vertex color carries the layering.
// Wing and tail feathers are real geometry. Vertex color carries root occlusion and
// per-feather tone; the detail map adds a shaft and barbs up close. Backlight lets a raised
// wing glow when the sun or a firework is behind it.
uniform sampler2D detail_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 plumage : source_color = vec3(0.93, 0.925, 0.905);
uniform float exposure = 1.0;
uniform float fuzz = 0.42;

void fragment() {
	ALBEDO = plumage * COLOR.rgb * exposure;
	NORMAL_MAP = texture(detail_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.35;
	ROUGHNESS = 0.68;
	SPECULAR = 0.24;
	RIM = fuzz;
	RIM_TINT = 0.75;
	BACKLIGHT = vec3(0.14);
}
