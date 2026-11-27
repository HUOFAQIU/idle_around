shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, blend_mix, skip_vertex_transform;

// Exact 1:1 GPU port of 41-weather.js + Three.js M.dof sky bokeh via depth_tex lookup at particle screen center
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float u_fade = 1.0;
uniform float u_focus_dist = 78.0;
uniform vec3 u_light_pos[12];
uniform vec3 u_light_col[12];
uniform int u_light_count = 0;
uniform vec3 u_amb = vec3(0.10, 0.14, 0.22);
uniform vec2 u_n = vec2(0.05, 0.0);
uniform vec3 u_vel_a = vec3(0.35, -0.12, 0.18);
uniform vec3 u_vel_b = vec3(0.0, 0.0, 0.0);
uniform vec2 u_sway_a = vec2(0.5, 0.5);
uniform vec2 u_sway_b = vec2(0.0, 0.0);
uniform vec2 u_size_a = vec2(0.03, 0.055);
uniform vec2 u_size_b = vec2(0.05, 0.05);
uniform vec4 u_col_a = vec4(0.75, 0.80, 0.95, 1.0);
uniform vec4 u_col_b = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 u_al_a = vec3(0.5, 0.0, 0.0);
uniform vec3 u_al_b = vec3(0.0, 0.0, 0.0);
uniform vec2 u_ya = vec2(-1.0, 9.0);
uniform vec2 u_yb = vec2(0.0, 1.0);

varying vec4 v_col;
varying vec2 v_uv;
varying float v_bokeh;

void vertex() {
	vec4 iseed = INSTANCE_CUSTOM;
	float is_b = step(iseed.w, u_n.y);
	float show = step(iseed.w, u_n.x + u_n.y);

	vec3 vel = mix(u_vel_a, u_vel_b, is_b);
	vec3 al = mix(u_al_a, u_al_b, is_b);
	vec2 sway = mix(u_sway_a, u_sway_b, is_b);
	vec2 sz = mix(u_size_a, u_size_b, is_b);
	vec2 yr = mix(u_ya, u_yb, is_b);
	vec4 cp = mix(u_col_a, u_col_b, is_b);

	float r1 = fract(iseed.w * 91.7 + iseed.x * 3.1);
	float r2 = fract(iseed.w * 357.3 + iseed.z * 5.7);
	float span = max(yr.y - yr.x, 0.01);

	vec3 p = vec3(iseed.x * 48.0, iseed.y * span, iseed.z * 48.0) + vel * TIME * (0.65 + 0.7 * r1);
	p.x += sin(TIME * sway.y * (0.6 + r2) + iseed.y * 40.0) * sway.x;
	p.z += cos(TIME * sway.y * (0.5 + r1) + iseed.x * 40.0) * sway.x;
	p.y += sin(TIME * sway.y * 0.7 + r1 * 30.0) * sway.x * 0.3;

	p.x = mod(p.x, 48.0) - 24.0;
	p.z = mod(p.z, 48.0) - 24.0;
	p.y = mod(p.y, span) + yr.x;

	vec4 mv = VIEW_MATRIX * vec4(p, 1.0);

	// Sample opaque background depth at particle screen center (exact match to Three.js M.dof depth buffer)
	vec4 clip_c = PROJECTION_MATRIX * mv;
	vec2 suv = clamp((clip_c.xy / max(abs(clip_c.w), 0.0001)) * 0.5 + 0.5, vec2(0.002), vec2(0.998));
	float d_bg = textureLod(depth_tex, suv, 0.0).x;
	float bokeh = 0.0;
	if (d_bg <= 0.0001 || d_bg >= 0.9999) {
		// Over empty dark sky -> full M.dof far-plane circular bokeh disc (matches image_30102e.png!)
		bokeh = 1.0;
	} else {
		vec4 vp_bg = INV_PROJECTION_MATRIX * vec4(suv * 2.0 - 1.0, d_bg, 1.0);
		float z_bg = -vp_bg.z / vp_bg.w;
		float dz = z_bg - u_focus_dist;
		if (dz > 0.0) {
			bokeh = clamp((dz - 3.6) / 12.5, 0.0, 1.0);
		} else {
			bokeh = clamp((-dz - 9.0) / 16.0, 0.0, 1.0) * 0.6;
		}
	}

	float base_sz = mix(sz.x, sz.y, r2);
	float size = base_sz * (1.0 + bokeh * 5.8);
	vec3 vv = (VIEW_MATRIX * vec4(vel, 0.0)).xyz;
	float vl = length(vv.xy);
	vec2 dir = vl > 0.0001 ? vv.xy / vl : vec2(0.0, 1.0);
	vec2 q = VERTEX.xy * 2.0;
	float stretch = 1.0 + al.z * vl * (1.0 - bokeh * 0.9);
	mv.xy += q.x * vec2(-dir.y, dir.x) * size + q.y * dir * size * stretch;

	if (show > 0.5) {
		VERTEX = mv.xyz;
	} else {
		VERTEX = vec3(0.0, 0.0, 10000.0);
	}

	vec3 L = u_amb;
	for (int i = 0; i < 12; i++) {
		if (i >= u_light_count) break;
		vec3 d = u_light_pos[i] - p;
		L += u_light_col[i] / (dot(d, d) + 3.0);
	}
	float tw = al.y > 0.0 ? pow(max(0.0, sin(TIME * al.y * (0.5 + r1) + r2 * 60.0)), 4.0) : 1.0;
	float ef = smoothstep(24.0, 21.0, max(abs(p.x), abs(p.z)))
		* smoothstep(yr.x, yr.x + 0.5, p.y)
		* smoothstep(yr.y, yr.y - 1.2, p.y);
	v_col = vec4(cp.rgb * mix(vec3(1.0), L, cp.a), al.x * tw * ef * u_fade);
	v_uv = q;
	v_bokeh = bokeh;
}

void fragment() {
	float r = length(v_uv);
	float disc = smoothstep(1.0, mix(0.25, 0.55, v_bokeh), r);
	// Whisper-soft optical energy falloff matching image_307223.png faint sky bokeh discs
	float energy = 1.0 / (1.0 + v_bokeh * v_bokeh * 46.0 + v_bokeh * 9.0);
	// Keep sky bokeh discs cleanly behind the mountain ridge silhouette
	if (v_bokeh > 0.85) {
		float d_pix = texture(depth_tex, SCREEN_UV).x;
		if (d_pix > 0.0001 && d_pix < 0.9999) {
			energy *= 0.25;
		}
	}
	float a = disc * v_col.a * energy;
	if (a < 0.003) {
		discard;
	}
	ALBEDO = v_col.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
