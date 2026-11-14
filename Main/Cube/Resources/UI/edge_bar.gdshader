shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 edge_color : source_color = vec4(0.32, 0.78, 1.0, 1.0);
uniform float energy = 1.3;

void fragment() {
	ALBEDO = edge_color.rgb * energy;
	ALPHA = 1.0;
}
