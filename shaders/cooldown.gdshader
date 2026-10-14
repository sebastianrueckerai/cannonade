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
	// shrink mode: the band's OUTER edge stays fixed just past the gun's foot, and its INNER
	// edge closes outward toward it over the reload, so the band thins to nothing at ready.
	// Shrinking the whole ring inward buried it under the gun mount by mid reload (round 27).
	float ro = 0.5;
	float ri = mix(inner, 0.5, shrink * progress);
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
		fade = 1.0 - smoothstep(0.92, 1.0, progress);
	}
	ALBEDO = color.rgb;
	ALPHA = color.a * fade;
}
