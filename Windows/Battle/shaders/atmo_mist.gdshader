shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix;

// P0-2: Depth-aware ground mist & point-light scattering aligned to 20-post.js:78-82
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 u_mist_amb = vec3(0.05, 0.08, 0.14);
uniform vec4 u_mist = vec4(-0.3, 0.42, 0.75, 0.10); // x=base_y, y=scale_h, z=density, w=light_gain
uniform vec3 u_light_pos[16];
uniform vec3 u_light_col[16];
uniform int u_light_count = 0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).x;
	if (d <= 0.0001 || d >= 0.9999) {
		discard;
	}
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	vec4 view_p = INV_PROJECTION_MATRIX * ndc;
	view_p.xyz /= view_p.w;
	vec3 P = (INV_VIEW_MATRIX * vec4(view_p.xyz, 1.0)).xyz;

	vec2 wind = vec2(TIME * 0.16, TIME * 0.09);
	float n = vn(P.xz * 0.16 + wind) * 0.65 + vn(P.xz * 0.47 - wind * 1.7) * 0.35;
	float tau = min(u_mist.z * exp(-(max(P.y, -1.0) - u_mist.x) / max(u_mist.y, 0.1)), 1.25)
		* smoothstep(0.34, 0.86, n)
		* smoothstep(-2.4, -1.1, P.y);
	float f = 1.0 - exp(-tau);
	if (f < 0.005) {
		discard;
	}

	vec3 L = u_mist_amb;
	vec3 Pm = P + vec3(0.0, 0.35, 0.0);
	for (int i = 0; i < 16; i++) {
		if (i >= u_light_count) break;
		vec3 dv = u_light_pos[i] - Pm;
		L += u_light_col[i] / (dot(dv, dv) + 2.0);
	}
	ALBEDO = L * u_mist.w;
	ALPHA = clamp(f, 0.0, 1.0);
}
