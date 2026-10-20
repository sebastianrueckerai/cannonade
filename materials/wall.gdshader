// The wall block: one mesh whose faces carry a region id in UV2.x (art/game/assets/3d/wall_block.py), each region
// multiplied by its own colour, so a block shows its owner's walkway toward the own walls beside it (D78) with
// one material and one draw call. `shade` darkens the whole block for the placement preview. GLES3 safe.
shader_type spatial;
render_mode cull_back;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 colors[13] : source_color;
uniform float shade = 1.0;

varying float region;

void vertex() {
	region = UV2.x;
}

void fragment() {
	ALBEDO = texture(tex, UV).rgb * colors[int(region + 0.5)].rgb * shade;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
