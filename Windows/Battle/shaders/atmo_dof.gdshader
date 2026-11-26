shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix;

// Exact 1:1 port of M.dof (20-post.js:91-121): true depth-aware miniature tilt-shift DoF
// Runs inside SubViewport right after atmo_ao (126) & atmo_mist (127) at render_priority=128
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec2 u_px = vec2(0.0010417, 0.0018519);
uniform vec4 u_dof = vec4(78.0, 4.5, 14.0, 7.5); // x=focus_dist, y=far_start, z=far_range, w=max_radius_px
uniform vec4 u_near = vec4(8.0, 14.0, 0.6, 0.25); // x=near_start, y=near_range, z=near_scale, w=early_exit_thr
uniform vec2 u_dither = vec2(0.0);

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

float linear_depth(vec2 uv, float d, mat4 inv_proj) {
	vec4 vp = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -vp.z / vp.w;
}

float coc_at(float z_dist) {
	float dz = z_dist - u_dof.x;
	if (dz > 0.0) {
		return clamp((dz - u_dof.y) / max(u_dof.z, 0.01), 0.0, 1.0) * u_dof.w;
	}
	return clamp((-dz - u_near.x) / max(u_near.y, 0.01), 0.0, 1.0) * u_dof.w * u_near.z;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	if (u_dof.w < 0.7) {
		discard;
	}
	float d_raw = texture(depth_tex, SCREEN_UV).x;
	if (d_raw <= 0.0001 || d_raw >= 0.9999) {
		discard;
	}
	float dc = linear_depth(SCREEN_UV, d_raw, INV_PROJECTION_MATRIX);
	float cc = coc_at(dc);

	float near_c = 0.0;
	if (cc < u_near.w) {
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7853982;
			vec2 o = vec2(cos(a), sin(a)) * u_px * u_dof.w * (mod(float(i), 2.0) < 0.5 ? 0.95 : 0.5);
			vec2 suv = clamp(SCREEN_UV + o, vec2(0.001), vec2(0.999));
			float s_raw = texture(depth_tex, suv).x;
			if (s_raw > 0.0001 && s_raw < 0.9999) {
				float sd = linear_depth(suv, s_raw, INV_PROJECTION_MATRIX);
				if (sd < dc) {
					near_c = max(near_c, coc_at(sd));
				}
			}
		}
		if (near_c < 0.35) {
			discard;
		}
	}

	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float tot = 1.0;
	float rad = 0.75;
	float ang = bayer4(FRAGCOORD.xy + u_dither) * 6.2831853;
	for (int i = 0; i < 32; i++) {
		ang += 2.39996323;
		vec2 tc = clamp(SCREEN_UV + vec2(cos(ang), sin(ang)) * u_px * rad, vec2(0.001), vec2(0.999));
		float s_raw = texture(depth_tex, tc).x;
		float sc = u_dof.w;
		if (s_raw > 0.0001 && s_raw < 0.9999) {
			float sd = linear_depth(tc, s_raw, INV_PROJECTION_MATRIX);
			sc = coc_at(sd);
			if (sd > dc) {
				sc = clamp(sc, 0.0, cc * 2.0);
			}
		} else {
			sc = clamp(u_dof.w, 0.0, cc * 2.0);
		}
		float m = smoothstep(rad - 0.5, rad + 0.5, sc);
		col += mix(col / tot, texture(screen_tex, tc).rgb, m);
		tot += 1.0;
		rad += 1.35 / rad;
		if (rad > u_dof.w) {
			break;
		}
	}
	float blend_a = smoothstep(0.20, 1.15, max(cc, near_c));
	ALBEDO = col / tot;
	ALPHA = blend_a;
}
