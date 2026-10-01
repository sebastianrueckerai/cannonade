shader_type spatial;
render_mode unshaded, cull_disabled;

// Radial cooldown indicator (replaces Unity's SpriteMask + circular timer sprite).
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.85);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	if (r > 0.5 || r < 0.32) {
		discard;
	}
	float a = atan(p.x, -p.y) / 6.2831853 + 0.5;
	if (a < progress) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
