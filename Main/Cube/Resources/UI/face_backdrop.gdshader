shader_type canvas_item;

uniform vec4 accent_color : source_color = vec4(0.30, 0.73, 1.0, 1.0);
uniform vec4 base_color : source_color = vec4(0.031, 0.043, 0.063, 1.0);

float grid_line(vec2 uv) {
	vec2 cells = fract(uv * 22.0) - 0.5;
	vec2 line_width = fwidth(uv * 22.0) * 1.2;
	vec2 lines = 1.0 - smoothstep(vec2(0.0), line_width, abs(cells));
	return max(lines.x, lines.y);
}

void fragment() {
	vec2 uv = UV;
	float top_glow = smoothstep(0.8, 0.0, distance(uv, vec2(0.12, 0.08)));
	float bottom_glow = smoothstep(0.6, 0.0, distance(uv, vec2(0.92, 0.92)));

	vec3 color = base_color.rgb;
	color = mix(color, accent_color.rgb, top_glow * 0.20 + bottom_glow * 0.06);
	color += accent_color.rgb * grid_line(uv) * 0.035;

	float vignette = smoothstep(0.34, 0.76, distance(uv, vec2(0.5)));
	color *= 1.0 - vignette * 0.32;

	float ring_distance = abs(length(uv - vec2(0.88, 0.10)) - 0.26);
	float ring = 1.0 - smoothstep(0.0, 0.0035, ring_distance);
	color += accent_color.rgb * ring * 0.12;

	COLOR = vec4(color, 1.0);
}
