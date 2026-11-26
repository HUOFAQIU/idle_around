shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray u_tex_a : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray u_tex_h : filter_linear_mipmap, repeat_enable;
uniform float u_bump = 0.055;
uniform float u_wind = 1.0;
uniform bool u_is_instanced = false;
uniform float u_wet = 0.0;

// Biome cover (snow / moss / ash / sand)
uniform vec4 u_cover = vec4(0.0, 0.55, 0.3, 0.5);
uniform vec3 u_cover_col = vec3(1.0, 1.0, 1.0);
uniform vec4 u_cover_p = vec4(0.7, 0.6, 0.0, 0.0);

varying vec4 v_surf;
varying vec3 v_wpos;
varying vec3 v_wnorm;
varying float v_flash;

float cw_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cw_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(cw_hash(i), cw_hash(i + vec2(1.0, 0.0)), f.x),
		mix(cw_hash(i + vec2(0.0, 1.0)), cw_hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	v_surf = CUSTOM0;
	v_flash = u_is_instanced ? INSTANCE_CUSTOM.r : 0.0;
	if (!u_is_instanced && v_surf.z > 0.0) {
		float ph = TIME * 1.6 + VERTEX.x * 0.9 + VERTEX.z * 0.7;
		float g = sin(ph) * 0.6 + sin(ph * 2.3 + 1.7) * 0.4;
		VERTEX.x += g * 0.07 * v_surf.z * u_wind;
		VERTEX.z += cos(ph * 0.8) * 0.05 * v_surf.z * u_wind;
		VERTEX.y += sin(ph * 1.9) * 0.02 * v_surf.z * u_wind;
	}
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float layer = floor(v_surf.x + 0.5);
	vec4 tex_a = texture(u_tex_a, vec3(UV, layer));
	vec3 vcol_lin = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	vec3 base_col = vcol_lin * tex_a.rgb * 2.0;
	float rough = clamp(v_surf.y * (1.15 - 0.3 * tex_a.a), 0.045, 1.0);

	// Screen-space procedural bump from height texture array FIRST (exact 10-gfx.js:206-220)
	vec3 base_n = NORMAL;
	float h0 = texture(u_tex_h, vec3(UV, layer)).a;
	vec2 d_uv_x = dFdx(UV);
	vec2 d_uv_y = dFdy(UV);
	float hx = texture(u_tex_h, vec3(UV + d_uv_x, layer)).a - h0;
	float hy = texture(u_tex_h, vec3(UV + d_uv_y, layer)).a - h0;
	vec3 d_pos_x = dFdx(VERTEX);
	vec3 d_pos_y = dFdy(VERTEX);
	vec3 r1 = cross(d_pos_y, NORMAL);
	vec3 r2 = cross(NORMAL, d_pos_x);
	float det = dot(d_pos_x, r1);
	if (abs(det) > 1e-6) {
		vec3 grad = sign(det) * (hx * r1 + hy * r2);
		NORMAL = normalize(abs(det) * NORMAL - u_bump * grad);
	}

	// Biome surface cover (snow, moss, ash, sand): normal smoothing + snowdrift/sand-ripple micro-bump (10-gfx.js:211-220)
	if (!u_is_instanced && u_cover.x > 0.01 && v_surf.w < 0.1 && layer > 0.5) {
		vec3 wn_b = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float n1 = cw_noise(v_wpos.xz * 0.8 + 17.0);
		float n2 = cw_noise(v_wpos.xz * 3.4 + v_wpos.y * 1.3);
		float n_cov = n1 * 0.62 + n2 * 0.38;
		float up_mask = smoothstep(u_cover.y, u_cover.y + 0.2, wn_b.y + (n_cov - 0.5) * u_cover.z);
		if (layer > 3.5 && layer < 4.5) {
			up_mask *= u_cover.w * smoothstep(0.80, 0.25, h0 - (n1 - 0.5) * 0.9);
		}
		float cov = clamp(up_mask * u_cover.x * (1.0 - clamp(v_surf.w * 40.0, 0.0, 1.0)), 0.0, 1.0);
		base_col = mix(base_col, u_cover_col * (0.90 + 0.20 * n1), cov);
		rough = mix(rough, u_cover_p.x, cov);
		NORMAL = normalize(mix(NORMAL, base_n, cov * u_cover_p.y));
		float ch = n_cov * u_cover_p.z + sin(dot(v_wpos.xz, vec2(5.1, 3.3)) + n1 * 7.0) * u_cover_p.w;
		vec3 cr1 = cross(d_pos_y, NORMAL);
		vec3 cr2 = cross(NORMAL, d_pos_x);
		float cdet = dot(d_pos_x, cr1);
		if (abs(cdet) > 1e-6 && cov > 0.01) {
			vec3 cgrad = sign(cdet) * (dFdx(ch) * cr1 + dFdy(ch) * cr2);
			NORMAL = normalize(abs(cdet) * NORMAL - cov * 0.35 * cgrad);
		}
	}

	if (u_wet > 0.01) {
		base_col = mix(base_col, base_col * vec3(0.68, 0.72, 0.78), u_wet * 0.65);
		rough = mix(rough, max(0.18, rough * 0.38), u_wet);
	}
	ALBEDO = base_col;
	ROUGHNESS = rough;
	METALLIC = (abs(layer - 5.0) < 0.5) ? 0.55 : 0.0;

	// Emissive + instanced hit-flash
	vec3 emis = base_col * v_surf.w * 6.0;
	if (v_flash > 0.01) {
		emis += vec3(1.0, 0.8, 0.55) * v_flash * 0.55;
	}
	EMISSION = emis;
}
