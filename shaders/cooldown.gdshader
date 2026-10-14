shader_type spatial;
render_mode unshaded, cull_disabled;

// A gun's reload ring (scripts/components/Cooldown.gd): a flat band whose outer edge stays put
// just past the gun's foot while its inner edge closes outward, so the band thins to nothing
// as progress runs from 0 to 1, fading over the last 8%.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float inner : hint_range(0.0, 0.5) = 0.36;

void fragment() {
	float r = length(UV - vec2(0.5));
	if (r > 0.5 || r < mix(inner, 0.5, progress)) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a * (1.0 - smoothstep(0.92, 1.0, progress));
}
