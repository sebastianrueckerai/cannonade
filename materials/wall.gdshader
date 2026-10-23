// The wall block: one mesh whose faces carry a region id in UV2.x (art/game/assets/3d/wall_block.py), each region
// multiplied by its own colour, so a block shows its owner's walkway toward the own walls beside it (D78) with
// one material and one draw call, flat stone under the colours since C22. A region whose colour has alpha 0 is
// dropped: the lego top's mid-side studs where the walkway crosses (D80). `shade` darkens the whole block for
// the placement preview, `tint` colours a preview that cannot be placed. GLES3 safe.
shader_type spatial;
render_mode cull_back;

uniform vec4 colors[17] : source_color;
uniform float shade = 1.0;
uniform vec3 tint : source_color = vec3(1.0);

varying float region;

void vertex() {
	region = UV2.x;
}

void fragment() {
	vec4 c = colors[int(region + 0.5)];
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * shade * tint;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
