shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// 3D miniature pixel-art alternating 3-claw slash VFX
// INSTANCE_CUSTOM = vec4(life_u, dir, tilt, scale)

varying float v_life;
varying float v_dir;
varying float v_tilt;

float bayer4(vec2 cell) {
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	int idx = y * 4 + x;
	const float m[16] = float[16](
		0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
		12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
		3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
		15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
	);
	return m[idx];
}

void vertex() {
	v_life = INSTANCE_CUSTOM.x;
	v_dir = INSTANCE_CUSTOM.y;
	v_tilt = INSTANCE_CUSTOM.z;
	float sc = max(INSTANCE_CUSTOM.w, 0.25);

	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 cam_right = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_up = INV_VIEW_MATRIX[1].xyz;
	vec3 cam_fwd = INV_VIEW_MATRIX[2].xyz;

	vec3 pos = world_pos
		+ cam_right * (VERTEX.x * sc)
		+ cam_up * (VERTEX.y * sc)
		+ cam_fwd * 0.28;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
}

void fragment() {
	const float GRID = 44.0;
	vec2 px = floor(UV * GRID);
	vec2 p = ((px + 0.5) / GRID) * 2.0 - 1.0;

	// Mirror horizontally for alternating left/right slash
	p.x *= (v_dir < 0.0) ? -1.0 : 1.0;

	// Diagonal slash angle (~42 deg) plus per-hit random tilt
	float ang = -0.74 + v_tilt;
	float ca = cos(ang);
	float sa = sin(ang);
	vec2 q = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);

	// 4-phase timeline:
	// 0.00..0.24 fast tear-in, 0.24..0.52 impact hold, 0.52..1.00 Bayer pixel erosion
	float reveal = clamp(v_life / 0.24, 0.0, 1.0);
	reveal = 1.0 - (1.0 - reveal) * (1.0 - reveal);
	float erode = clamp((v_life - 0.52) / 0.48, 0.0, 1.0);

	float best_d = 99.0;
	float best_t = 0.0;

	for (int i = -1; i <= 1; i++) {
		float fi = float(i);
		float is_center = 1.0 - abs(fi);
		float half_len = mix(0.62, 0.84, is_center);
		float y_ofs = fi * 0.24;
		float arc = 0.14 * (1.0 - clamp((q.x * q.x) / (half_len * half_len), 0.0, 1.0));
		float cy = y_ofs + arc;

		float t = (q.x + half_len) / (2.0 * half_len);
		if (t < -0.05 || t > reveal + 0.04 || t > 1.04) {
			continue;
		}
		float tc = clamp(t, 0.0, 1.0);
		// Sharp tapered blade profile: thicker center, razor-sharp tips
		float profile = sin(tc * 3.14159265);
		float tip_bias = mix(0.85, 1.15, 1.0 - tc);
		float half_w = mix(0.052, 0.088, is_center) * pow(max(profile, 0.0), 0.72) * tip_bias;
		// Slightly thicken during impact freeze frame
		float freeze_boost = (v_life >= 0.20 && v_life <= 0.48) ? 1.12 : 1.0;
		half_w *= freeze_boost;

		float d = abs(q.y - cy) - half_w;
		// Clip smoothly at sweeping head
		float head_d = (t - reveal) * half_len * 2.0;
		d = max(d, head_d);
		if (d < best_d) {
			best_d = d;
			best_t = tc;
		}
	}

	const float MID_BAND = 0.038;
	const float OUTLINE_BAND = 0.082;
	if (best_d > OUTLINE_BAND) {
		discard;
	}

	// Ordered Bayer pixel erosion from tail (t=0) toward tip (t=1)
	if (erode > 0.001) {
		float threshold = erode * 1.35 - best_t * 0.35 + max(best_d, 0.0) * 3.0;
		if (threshold > bayer4(px)) {
			discard;
		}
	}

	vec3 col_core = vec3(1.0, 0.965, 0.878);
	vec3 col_mid = vec3(0.949, 0.545, 0.188);
	vec3 col_out = vec3(0.106, 0.059, 0.051);

	vec3 col = col_out;
	if (best_d <= 0.0) {
		col = col_core;
	} else if (best_d <= MID_BAND) {
		col = col_mid;
	}

	// Brighten core slightly during FR2 impact hold
	if (v_life >= 0.20 && v_life <= 0.45 && best_d <= MID_BAND) {
		col = mix(col, vec3(1.0, 0.99, 0.94), 0.35);
	}

	ALBEDO = col;
	ALPHA = 1.0;
}
