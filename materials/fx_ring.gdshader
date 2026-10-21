shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never;

uniform vec4 ring_color : source_color = vec4(1.0, 0.85, 0.55, 0.75);
uniform float progress : hint_range(0.0, 1.0) = 0.1;
uniform float width : hint_range(0.05, 0.5) = 0.16;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float d = abs(r - progress);
	float a = smoothstep(width, 0.0, d) * (1.0 - progress);
	ALBEDO = ring_color.rgb;
	ALPHA = a * ring_color.a;
}
