shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

// Expanding shockwave ring: progress drives the band outwards from the centre.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;
	float r = progress;
	float band = smoothstep(r - 0.38, r - 0.16, d) * (1.0 - smoothstep(r - 0.16, r, d));
	float core = (1.0 - smoothstep(0.0, 0.45, d)) * (1.0 - progress);
	ALBEDO = color.rgb;
	ALPHA = clamp(band + core * 0.7, 0.0, 1.0) * (1.0 - progress) * color.a;
}
