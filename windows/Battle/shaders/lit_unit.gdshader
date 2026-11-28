shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// GPU Procedural Skeletal Rigging Shader for Battle Units
// Each unit is 1 MultiMesh instance (100% baked geometry per archetype).
// Vertex CUSTOM0 = vec4(pivot.x, pivot.y, pivot.z, part_id)
// INSTANCE_CUSTOM = vec4(phase, swing, flash, mv)

uniform sampler2DArray u_tex_a : filter_linear_mipmap, repeat_enable;
uniform vec3 u_anim_move = vec3(1.0, 1.0, 1.0);
uniform vec3 u_anim_atk = vec3(0.40, 0.65, 1.0);
uniform vec4 u_flash_style = vec4(1.0, 0.8, 0.55, 0.55);

varying float v_flash;

vec3 rot_x(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
}

vec3 rot_y(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
}

vec3 rot_z(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(p.x * c - p.y * s, p.x * s + p.y * c, p.z);
}

void vertex() {
	float phase = INSTANCE_CUSTOM.r;
	float swing = INSTANCE_CUSTOM.g;
	v_flash = INSTANCE_CUSTOM.b;
	float mv_raw = INSTANCE_CUSTOM.a;
	float cast_u = max(0.0, mv_raw - 2.0);
	float mv = clamp(mv_raw > 1.5 ? 0.0 : mv_raw, 0.0, 1.0);
	float idle_w = (1.0 - mv) * u_anim_move.z;

	vec3 piv = CUSTOM0.xyz;
	float pid = floor(CUSTOM0.w + 0.5);

	vec3 v = VERTEX;
	vec3 n = NORMAL;

	// Attack swing curve (matches 50-rig.js)
	float atk_arm = 0.0;
	float atk_twist = 0.0;
	float atk_lunge = 0.0;
	if (swing > 0.01) {
		float wu = max(u_anim_atk.x, 0.05);
		float st = max(u_anim_atk.y, wu + 0.05);
		float lg = u_anim_atk.z;
		float atk_u = 1.0 - clamp(swing, 0.0, 1.0);
		if (atk_u < wu) {
			float w = atk_u / wu;
			float ew = w * w * (3.0 - 2.0 * w);
			atk_arm = -2.15 * ew * lg;
			atk_twist = -0.40 * ew * lg;
			atk_lunge = -0.08 * ew * lg;
		} else if (atk_u < st) {
			float w = (atk_u - wu) / (st - wu);
			float ew = 1.0 - pow(1.0 - w, 3.0);
			atk_arm = mix(-2.15, 0.80, ew) * lg;
			atk_twist = mix(-0.40, 0.50, ew) * lg;
			atk_lunge = mix(-0.08, 0.22, ew) * lg;
		} else {
			float w = (atk_u - st) / max(1.0 - st, 0.05);
			atk_arm = mix(0.80, 0.0, w) * lg;
			atk_twist = mix(0.50, 0.0, w) * lg;
			atk_lunge = mix(0.22, 0.0, w) * lg;
		}
	}

	if (pid >= 1.0 && pid <= 5.5) {
		// Humanoid family
		float bob = abs(sin(phase)) * 0.075 * mv;
		float leg_a = sin(phase) * 0.60 * mv;
		float arm_a = -sin(phase) * 0.52 * mv;

		if (pid < 1.5) {
			// Left leg
			vec3 p = v - piv;
			v = rot_x(p, leg_a) + piv;
			n = rot_x(n, leg_a);
		} else if (pid < 2.5) {
			// Right leg
			vec3 p = v - piv;
			v = rot_x(p, -leg_a) + piv;
			n = rot_x(n, -leg_a);
		} else if (pid < 3.5) {
			// Torso + Head
			vec3 p = v - piv;
			p = rot_y(p, atk_twist);
			n = rot_y(n, atk_twist);
			v = p + piv + vec3(0.0, 0.0, atk_lunge * 0.38);
		} else if (pid < 4.5) {
			// Left arm
			float la = -arm_a * 0.72;
			if (cast_u > 0.01) {
				la = mix(la, -2.35, clamp(cast_u, 0.0, 1.0));
			}
			vec3 p = v - piv;
			p = rot_x(p, la);
			n = rot_x(n, la);
			v = p + piv;
			vec3 tp = v - vec3(0.0, 0.56, 0.0);
			v = rot_y(tp, atk_twist) + vec3(0.0, 0.56, atk_lunge * 0.38);
			n = rot_y(n, atk_twist);
		} else {
			// Right arm + Weapon
			float ra = (swing > 0.01) ? atk_arm : arm_a;
			if (cast_u > 0.01) {
				ra = mix(ra, -2.55, clamp(cast_u, 0.0, 1.0));
			}
			vec3 p = v - piv;
			p = rot_x(p, ra);
			n = rot_x(n, ra);
			v = p + piv;
			vec3 tp = v - vec3(0.0, 0.56, 0.0);
			v = rot_y(tp, atk_twist) + vec3(0.0, 0.56, atk_lunge * 0.38);
			n = rot_y(n, atk_twist);
		}
		float breath = sin(TIME * 2.8 + phase) * 0.025 * idle_w;
		v.y += bob + (pid >= 2.5 ? breath : 0.0);
	} else if (pid > 5.5 && pid < 6.5) {
		// Wraith float & sway
		float tw = TIME + phase * 0.35;
		v = rot_z(v, sin(tw * 1.3) * 0.06);
		n = rot_z(n, sin(tw * 1.3) * 0.06);
		v.y += sin(tw * 2.1) * 0.07;
	} else if (pid >= 11.0 && pid <= 13.5) {
		// Quadruped (Rat, Wolf)
		float bob = abs(sin(phase)) * 0.045 * mv;
		float lng = sin(clamp(swing, 0.0, 1.0) * 3.14159);
		if (pid < 11.5) {
			float a = sin(phase) * 0.72 * mv;
			v = rot_x(v - piv, a) + piv;
			n = rot_x(n, a);
		} else if (pid < 12.5) {
			float a = -sin(phase) * 0.72 * mv;
			v = rot_x(v - piv, a) + piv;
			n = rot_x(n, a);
		}
		v.y *= 1.0 + sin(TIME * 3.0 + phase) * 0.03 * idle_w;
		v.y += bob + lng * 0.14;
		v.z += lng * 0.28;
	} else if (pid > 19.5 && pid < 20.5) {
		// Slime / Bog Toad squash & hop
		float hop = abs(sin(phase * 0.6)) * mv;
		float lng = sin(clamp(swing, 0.0, 1.0) * 3.14159);
		float idle_breath = sin(TIME * 3.6 + phase) * 0.065 * idle_w;
		float sy = 1.0 + (hop - 0.35) * 0.34 * mv + idle_breath;
		float sxz = 1.0 / sqrt(max(sy, 0.4));
		v.x *= sxz;
		v.z *= sxz;
		v.y *= sy;
		v.x += sin(TIME * 2.3 + phase) * 0.025 * v.y * idle_w;
		v.y += hop * 0.28 + lng * 0.14;
		v.z += lng * 0.22;
	} else if (pid >= 31.0 && pid <= 33.5) {
		// Flyer (Bat, Gargoyle, Wisp)
		float flap = sin(phase) * 0.78;
		if (pid < 31.5) {
			v = rot_z(v - piv, flap) + piv;
			n = rot_z(n, flap);
		} else if (pid < 32.5) {
			v = rot_z(v - piv, -flap) + piv;
			n = rot_z(n, -flap);
		}
		v.y += sin(phase * 0.5) * 0.08;
	} else if (pid >= 41.0 && pid <= 43.5) {
		// Bug / Spider
		float a = sin(phase * 1.6) * 0.36 * mv;
		float lng = sin(clamp(swing, 0.0, 1.0) * 3.14159);
		if (pid < 41.5) {
			v = rot_y(v - piv, a) + piv;
			n = rot_y(n, a);
		} else if (pid < 42.5) {
			v = rot_y(v - piv, -a) + piv;
			n = rot_y(n, -a);
		}
		v.y *= 1.0 + sin(TIME * 3.2 + phase) * 0.03 * idle_w;
		v.y += lng * 0.12;
		v.z += lng * 0.24;
	} else if (pid > 49.5 && pid < 50.5) {
		// Serpent (Snake, Fu): S-curve slither + coiled head lunge driven by UnitAnimConfig
		float hw = clamp(piv.y, 0.0, 1.0);
		float slither = sin(phase * 1.15 - v.z * 4.2 * u_anim_move.y) * 0.085 * u_anim_move.x * mv;
		float sway = sin(TIME * 2.6 + phase) * 0.035 * u_anim_move.z * hw;
		v.x += slither + sway;
		v.y += sin(TIME * 3.2 + phase) * 0.022 * u_anim_move.z * hw;
		if (swing > 0.01) {
			v.z += atk_lunge * 1.65 * hw;
			v.y += max(atk_lunge, 0.0) * 0.55 * hw;
		}
	}

	VERTEX = v;
	NORMAL = normalize(n);
}

void fragment() {
	vec4 tex_a = texture(u_tex_a, vec3(UV, 0.0));
	vec3 vcol_lin = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	vec3 base_col = vcol_lin * tex_a.rgb * 2.0;
	ALBEDO = base_col;
	ROUGHNESS = clamp(0.84 * (1.15 - 0.3 * tex_a.a), 0.1, 1.0);
	METALLIC = 0.0;
	if (v_flash > 0.01) {
		EMISSION = u_flash_style.rgb * v_flash * u_flash_style.a;
	}
}
