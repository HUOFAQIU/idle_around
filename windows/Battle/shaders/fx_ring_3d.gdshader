shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

varying vec4 v_col;
varying float v_u;
varying float v_width;

void vertex() {
	v_col = COLOR;
	v_u = INSTANCE_CUSTOM.r;
	v_width = max(INSTANCE_CUSTOM.g, 0.06);
	VERTEX.y += INSTANCE_CUSTOM.b * v_u;
}

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	float edge = mix(0.28, 0.92, v_u);
	float band = 1.0 - smoothstep(0.0, v_width, abs(r - edge));
	float inner_glow = (1.0 - smoothstep(0.0, edge, r)) * 0.16 * (1.0 - v_u);
	float fade = sin(clamp(v_u, 0.0, 1.0) * 3.14159);
	float alpha = clamp((band + inner_glow) * fade * v_col.a, 0.0, 1.0);
	if (alpha < 0.01) {
		discard;
	}
	ALBEDO = v_col.rgb;
	ALPHA = alpha;
}
