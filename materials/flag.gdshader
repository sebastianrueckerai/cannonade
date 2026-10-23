// The castle flag's cloth (I115): a plane whose UV.x runs from the pole (0) to the fly (1). The wave
// hangs stiff at the pole and loose at the fly. `albedo` is the owner's colour (Castle.gd repaints it),
// `alpha` the placement fades; both are set from the start so shader reads find them. GLES3 safe.
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(0.612, 0.478, 0.310, 1.0);  // the neutral brown #9c7a4f
uniform float alpha = 1.0;

void vertex() {
	float k = UV.x * UV.x;
	VERTEX += NORMAL * sin(TIME * 3.0 + UV.x * 6.0 + UV.y * 2.0) * 0.06 * k;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a * alpha;
	ROUGHNESS = 1.0;
}
