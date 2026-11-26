// Adapted from Dylearn's Grass.gdshader & clouds.gdshaderinc (MIT License)
// Tuned for Cinderwatch AroundMe Morning Forest Clearing:
// - Seamless velvety overlapping pixel-art grass carpet (5fps stepped wind waves)
// - Cohesive 3-patch lush green palette + subtle sunlit sprout accents
// - Real-time 64-unit trampling displacement

shader_type spatial;
render_mode depth_prepass_alpha, depth_draw_opaque;

group_uniforms colours_and_textures;
uniform float u_rain = 0.0;
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo1 : source_color = vec4(0.39, 0.54, 0.16, 1.0);

uniform vec4 albedo2 : source_color = vec4(0.46, 0.59, 0.19, 1.0);
uniform float albedo2_scale = 0.065;
uniform float albedo2_threshold = 0.52;
uniform sampler2D albedo2_noise : repeat_enable;

uniform vec4 albedo3 : source_color = vec4(0.42, 0.56, 0.17, 1.0);
uniform float albedo3_scale = 0.055;
uniform float albedo3_threshold = 0.50;
uniform sampler2D albedo3_noise : repeat_enable;

uniform float accent_frequency1 = 0.004;
uniform sampler2D accent_texture1 : source_color, filter_nearest;
uniform vec4 accent_albedo1 : source_color = vec4(0.56, 0.72, 0.18, 1.0);
uniform float accent_height1 = 0.08;
uniform float accent_scale1 = 1.05;

uniform float accent_probability2 = 0.0022;
uniform sampler2D accent_texture2 : source_color, filter_nearest;
uniform vec4 accent_albedo2 : source_color = vec4(0.88, 0.84, 0.48, 1.0);
uniform float accent_height2 = 0.14;
uniform float accent_scale2 = 1.02;

group_uniforms animation;
uniform float framerate = 5.0;
uniform bool quantised = true;
uniform bool world_space_sway = true;
uniform float world_sway_angle = 42.0;
uniform float fake_perspective_scale = 0.25;
uniform sampler2D wind_noise : repeat_enable;
uniform float wind_noise_threshold = 0.36;
uniform float wind_noise_scale = 0.065;
uniform float wind_noise_speed = 0.024;
uniform vec2 wind_noise_direction = vec2(0.7, 0.7);
uniform float noise_diverge_angle = 12.0;

uniform bool view_space_sway = true;
uniform float view_sway_speed = 0.12;
uniform float view_sway_angle = 7.0;

group_uniforms character_displacement;
uniform bool character_displacement = true;
uniform float player_displacement_angle_z = 48.0;
uniform float player_displacement_angle_x = 48.0;
uniform float radius_exponent = 1.15;
const int CHARACTER_COUNT = 64;
uniform vec4 character_positions[64];
uniform int character_active_count = 0;

group_uniforms lighting;
uniform int cuts = 3;
uniform float wrap = 0.28;
uniform float steepness = 1.18;
uniform float threshold_gradient_size = 0.35;

varying float wind_noise_sample;
varying float id_seed1;
varying float id_seed2;
varying vec3 model_origin;
varying vec3 object_origin;
varying float player_displacement_fake_perspective;

vec2 rotate_vec2(vec2 v, float angle_deg) {
	float a = angle_deg * (PI / 180.0);
	return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a));
}

float location_seed(vec2 loc) {
	return fract(sin(dot(loc, vec2(12.9898, 78.233))) * 43758.5453123);
}

float random_f(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

mat4 rotateAroundAxis(vec3 axis, float angle) {
	axis = normalize(axis);
	float c = cos(angle);
	float s = sin(angle);
	float oc = 1.0 - c;
	return mat4(
		vec4(oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 0.0),
		vec4(oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s, 0.0),
		vec4(oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

mat4 view_space_rotate(float angle) {
	return mat4(
		vec4(cos(angle), -sin(angle), 0.0, 0.0),
		vec4(sin(angle), cos(angle), 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}

void vertex() {
	float iid = float(INSTANCE_ID);
	id_seed1 = random_f(iid);
	id_seed2 = random_f(iid + PI);
	if (id_seed1 < accent_frequency1) {
		VERTEX.y += accent_height1;
		VERTEX *= accent_scale1;
	} else if (id_seed2 < accent_probability2) {
		VERTEX.y += accent_height2;
		VERTEX *= accent_scale2;
	}

	object_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float seed = 10.0 * location_seed(object_origin.xz);
	float frametime = 1.0 / max(framerate, 1.0);
	float phase = mod(seed, frametime);
	float time = TIME;
	if (quantised) {
		time = round((time + phase) * framerate) / framerate;
	}

	vec2 wd1 = normalize(rotate_vec2(wind_noise_direction, noise_diverge_angle));
	vec2 wd2 = normalize(rotate_vec2(wind_noise_direction, -noise_diverge_angle));
	float w_spd = wind_noise_speed * mix(1.0, 1.8, u_rain);
	float wn1 = texture(wind_noise, object_origin.xz * wind_noise_scale + time * w_spd * wd1).r;
	float wn2 = texture(wind_noise, object_origin.xz * (wind_noise_scale * 0.8) + time * w_spd * wd2 * 0.93).r;
	wind_noise_sample = (clamp(wn1 * wn2 + wind_noise_threshold, 0.0, 1.0) - 0.5) * 2.0;

	float world_sway = wind_noise_sample * radians(world_sway_angle * mix(1.0, 1.28, u_rain));
	vec3 wind_world_axis = (vec4(wind_noise_direction.y, 0.0, -wind_noise_direction.x, 0.0) * INV_VIEW_MATRIX).xyz;
	if (length(wind_world_axis) < 0.001) {
		wind_world_axis = vec3(1.0, 0.0, 0.0);
	}
	mat4 world_rotation = rotateAroundAxis(wind_world_axis, world_sway);

	float model_sway = sin((time + seed) * view_sway_speed * 2.0 * PI) * radians(view_sway_angle);
	mat4 model_rotation = view_space_rotate(model_sway);

	float disp_x = 0.0;
	float disp_y = 0.0;
	if (character_displacement && character_active_count > 0) {
		int cnt = min(character_active_count, CHARACTER_COUNT);
		vec2 cam_fwd = normalize(CAMERA_DIRECTION_WORLD.xz);
		vec2 cam_right = normalize(vec2(CAMERA_DIRECTION_WORLD.z, -CAMERA_DIRECTION_WORLD.x));
		for (int i = 0; i < cnt; i++) {
			vec4 cp = character_positions[i];
			float rad = max(cp.w, 0.1);
			vec2 diff = object_origin.xz - cp.xz;
			float d = length(diff) / rad;
			if (d < 1.0) {
				float str = clamp(pow(1.0 - d, radius_exponent), 0.0, 1.0);
				vec2 dir = (d > 0.001) ? (diff / (d * rad)) : vec2(1.0, 0.0);
				disp_x += str * dot(cam_right, dir);
				disp_y += str * dot(cam_fwd, dir);
			}
		}
		disp_x = clamp(disp_x, -1.0, 1.0);
		disp_y = clamp(disp_y, -1.0, 1.0);
	}
	player_displacement_fake_perspective = disp_y;

	if (view_space_sway) {
		VERTEX = (model_rotation * vec4(VERTEX, 1.0)).xyz;
	}
	if (character_displacement && (abs(disp_x) > 0.001 || abs(disp_y) > 0.001)) {
		mat4 disp_rot = rotateAroundAxis(vec3(0.0, 0.0, 1.0), disp_x * radians(player_displacement_angle_z))
			* rotateAroundAxis(vec3(1.0, 0.0, 0.0), disp_y * radians(player_displacement_angle_x));
		VERTEX = (disp_rot * vec4(VERTEX, 1.0)).xyz;
	}
	if (world_space_sway) {
		VERTEX = (world_rotation * vec4(VERTEX, 1.0)).xyz;
	}

	float sc_x = length(MODEL_MATRIX[0].xyz);
	float sc_y = length(MODEL_MATRIX[1].xyz);
	mat4 modified_mv = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * sc_x, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * sc_y, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz, 0.0),
		MODEL_MATRIX[3]
	);
	model_origin = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	MODELVIEW_MATRIX = modified_mv;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV;
	uv.x -= 0.5;
	float w_samp = wind_noise_sample * fake_perspective_scale;
	if (world_space_sway) {
		w_samp *= dot(normalize(CAMERA_DIRECTION_WORLD.xz), normalize(wind_noise_direction));
		uv.x *= (1.0 - uv.y) * w_samp + 1.0;
	}
	if (character_displacement) {
		uv.x *= (1.0 - uv.y) * -player_displacement_fake_perspective + 1.0;
	}
	uv.x = clamp(uv.x + 0.5, 0.0, 1.0);

	vec4 albedo_tex = texture(albedo_texture, uv);
	float n2 = texture(albedo2_noise, object_origin.xz * albedo2_scale).r;
	float n3 = texture(albedo3_noise, object_origin.xz * albedo3_scale).r;
	float t2 = smoothstep(albedo2_threshold - 0.14, albedo2_threshold + 0.14, n2);
	float t3 = smoothstep(albedo3_threshold - 0.14, albedo3_threshold + 0.14, n3);
	vec3 col = mix(albedo1.rgb, albedo2.rgb, t2);
	col = mix(col, albedo3.rgb, t3) * albedo_tex.rgb;
	if (id_seed1 < accent_frequency1) {
		albedo_tex = texture(accent_texture1, uv);
		col = accent_albedo1.rgb * albedo_tex.rgb;
	} else if (id_seed2 < accent_probability2) {
		albedo_tex = texture(accent_texture2, uv);
		col = accent_albedo2.rgb * albedo_tex.rgb;
	}

	// Subtle vertical root-to-tip gradient so overlapping grass reads velvety & deep
	float tip_grad = mix(1.08, 0.84, uv.y);
	col *= tip_grad;

	// Subtle forest canopy shade far outside playable clearing
	float r = length(object_origin.xz);
	float edge_t = clamp((r - 22.0) / 10.0, 0.0, 1.0);
	col = mix(col, col * 0.86, edge_t);

	col = mix(col, col * vec3(0.72, 0.84, 0.88), u_rain * 0.78);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.50, u_rain);
	// Soft ambient bounce so dense grass stays velvety instead of crushing black in SSAO
	EMISSION = col * vec3(0.055, 0.065, 0.035);
	LIGHT_VERTEX = model_origin;
	ALPHA = albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

void light() {
	float NdotL = max(dot(NORMAL, LIGHT), 0.0);
	if (LIGHT_IS_DIRECTIONAL) {
		float diffuse_amount = clamp((NdotL + wrap) * ATTENUATION * steepness, 0.0, 1.0);

		float cut = 1.0 / float(max(cuts, 1));
		float nearest_k = floor(diffuse_amount / cut + 0.5);
		float thresh = nearest_k * cut;
		float stepped = diffuse_amount;
		if (threshold_gradient_size > 0.0 && nearest_k >= 0.0 && nearest_k <= float(cuts)) {
			float hw = 0.5 * cut * threshold_gradient_size;
			float lo = max(0.0, thresh - hw);
			float hi = min(1.0, thresh + hw);
			float bl = (hi > lo) ? smoothstep(lo, hi, diffuse_amount) : step(thresh, diffuse_amount);
			stepped = clamp(mix(thresh, min(thresh + cut, 1.0), bl), 0.0, 1.0);
		}
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * stepped * 1.24;
	} else {
		float att = clamp((NdotL * 0.65 + 0.35) * ATTENUATION, 0.0, 1.0);
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR / PI * att * 1.25;
	}
}
