shader_type spatial;
render_mode unshaded, cull_disabled;

// Radial cooldown indicator (replaces Unity's SpriteMask + circular timer sprite).
// shrink = 0: the ring is eaten away by angle as progress grows (the shipped pie wipe).
// shrink = 1: the ring's outer radius shrinks toward the inner one as progress grows, so a
//             ring round a gun's base closes in on the gun and vanishes at ready (round 27).
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float shrink : hint_range(0.0, 1.0) = 0.0;
uniform float inner : hint_range(0.0, 0.5) = 0.32;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	// shrink mode: the band keeps its full width and the whole ring scales down toward the
	// centre over the reload, fading out over the last tenth
	float s = mix(1.0, 0.25, shrink * progress);
	float ro = 0.5 * s;
	float ri = inner * s;
	if (r > ro || r < ri) {
		discard;
	}
	float fade = 1.0;
	if (shrink < 0.5) {
		float a = atan(p.x, -p.y) / 6.2831853 + 0.5;
		if (a < progress) {
			discard;
		}
	} else {
		fade = 1.0 - smoothstep(0.9, 1.0, progress);
	}
	ALBEDO = color.rgb;
	ALPHA = color.a * fade;
}
