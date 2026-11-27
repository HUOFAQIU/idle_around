shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mul;

// P0-1: Screen-space AO ported from 20-post.js:64-76 (renders before atmo_mist via render_priority=126)
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec2 u_px = vec2(0.0010417, 0.0018519);
uniform vec3 u_ao = vec3(1.0, 18.0, 0.7); // x=strength, y=radius(px), z=max_dist_sq
uniform vec2 u_dither = vec2(0.0);
uniform vec4 u_dof_fade = vec4(78.0, 3.6, 12.5, 1.0); // x=focus_dist, y=far_start, z=far_range, w=dof_enabled

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

vec3 wpos_from_depth(vec2 uv, float d, mat4 inv_proj, mat4 inv_view) {
	vec4 ndc = vec4(uv * 2.0 - 1.0, d, 1.0);
	vec4 vp = inv_proj * ndc;
	vp.xyz /= vp.w;
	return (inv_view * vec4(vp.xyz, 1.0)).xyz;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).x;
	// Reverse-Z (Vulkan Forward+: far=0.0) and standard-Z (Compatibility: far=1.0)
	if (d <= 0.0001 || d >= 0.9999) {
		discard;
	}

	vec3 P = wpos_from_depth(SCREEN_UV, d, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);

	vec2 uv_r = clamp(SCREEN_UV + vec2(u_px.x, 0.0), vec2(0.001), vec2(0.999));
	vec2 uv_l = clamp(SCREEN_UV - vec2(u_px.x, 0.0), vec2(0.001), vec2(0.999));
	vec2 uv_u = clamp(SCREEN_UV + vec2(0.0, u_px.y), vec2(0.001), vec2(0.999));
	vec2 uv_d = clamp(SCREEN_UV - vec2(0.0, u_px.y), vec2(0.001), vec2(0.999));

	float dr = texture(depth_tex, uv_r).x;
	float dl = texture(depth_tex, uv_l).x;
	float du = texture(depth_tex, uv_u).x;
	float dd = texture(depth_tex, uv_d).x;

	vec3 ddx = abs(dr - d) < abs(d - dl)
		? wpos_from_depth(uv_r, dr, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX) - P
		: P - wpos_from_depth(uv_l, dl, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	vec3 ddy = abs(du - d) < abs(d - dd)
		? wpos_from_depth(uv_u, du, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX) - P
		: P - wpos_from_depth(uv_d, dd, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);

	vec3 N = cross(ddx, ddy);
	if (dot(N, N) < 1e-10) {
		discard;
	}
	N = normalize(N);
	// Orient normal toward camera (INV_VIEW_MATRIX[2].xyz points toward camera; -Z is camera forward)
	vec3 cam_fwd = -INV_VIEW_MATRIX[2].xyz;
	if (dot(N, cam_fwd) > 0.0) {
		N = -N;
	}

	float occ = 0.0;
	float ang = bayer4(FRAGCOORD.xy + u_dither) * 6.2831853;
	for (int i = 0; i < 10; i++) {
		float fi = (float(i) + 0.5) / 10.0;
		float a = ang + float(i) * 2.39996;
		vec2 suv = clamp(SCREEN_UV + vec2(cos(a), sin(a)) * u_ao.y * sqrt(fi) * u_px, vec2(0.001), vec2(0.999));
		float sd = texture(depth_tex, suv).x;
		if (sd <= 0.0001 || sd >= 0.9999) {
			continue;
		}
		vec3 V = wpos_from_depth(suv, sd, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX) - P;
		float vv = dot(V, V);
		occ += max(0.0, dot(V, N) - 0.035) / (vv + 0.03) * step(vv, u_ao.z);
	}
	// Smoothly attenuate sharp AO inside far DoF blur zone so AO creases don't stamp crisp dark halos over blurred trees
	vec4 vp_c = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float z_dist = -vp_c.z / vp_c.w;
	float dof_t = clamp((z_dist - u_dof_fade.x - u_dof_fade.y) / max(u_dof_fade.z, 0.01), 0.0, 1.0) * u_dof_fade.w;
	float ao_fade = mix(1.0, 0.22, smoothstep(0.0, 0.75, dof_t));
	float ao = clamp(1.0 - occ * u_ao.x * ao_fade * 0.1, 0.0, 1.0);
	ALBEDO = vec3(ao);
}
