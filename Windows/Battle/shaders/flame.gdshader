shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// Exact 1:1 port of SpriteBatch type==1 (4-band roaring bonfire) & type==2 (radial halo) from 40-fx.js:136-149
uniform float u_seed = 0.0;
uniform float u_intensity = 1.0;
uniform float u_is_halo = 0.0;
uniform bool u_is_instanced = false;
uniform vec3 u_col = vec3(1.0, 0.58, 0.22);

varying float v_seed;
varying float v_int;

float h2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x),
		mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	v_seed = u_is_instanced ? INSTANCE_CUSTOM.r : u_seed;
	v_int = u_is_instanced ? INSTANCE_CUSTOM.g : u_intensity;
	// Spherical billboard preserving local quad scale
	vec3 sx = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 m = mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * sx.x, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * sx.y, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * sx.z, 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, (1.0 - UV.y) * 2.0 - 1.0);
	float r = length(p);

	if (u_is_halo > 0.5) {
		// type == 2: pow(max(0, 1 - r), 2.4) warm golden bloom halo
		float a = pow(max(0.0, 1.0 - r), 2.4);
		ALBEDO = u_col * a * v_int;
		ALPHA = clamp(a * v_int, 0.0, 1.0);
	} else {
		// Volumetric soft-edged procedural flame with connected tongues + warm radial aura (no hard card edge or detached blobs)
		float y = clamp(p.y * 0.5 + 0.5, 0.0, 1.0);
		float n1 = n2(vec2(p.x * 2.4 + v_seed * 5.0, y * 3.2 - TIME * 4.8));
		float n2v = n2(vec2(p.x * 5.4 - v_seed * 3.0, y * 7.0 - TIME * 7.6));
		float x = p.x + (n1 - 0.5) * 0.48 * y + (n2v - 0.5) * 0.16 * y;
		float w = mix(0.56, 0.03, pow(y, 0.82)) * (0.85 + 0.25 * smoothstep(0.0, 0.22, y));
		float body = 1.0 - smoothstep(w * 0.12, w * 1.08, abs(x));
		float edge_fade = smoothstep(0.96, 0.68, abs(p.x)) * smoothstep(0.96, 0.70, y) * smoothstep(0.0, 0.12, y);
		// Bind noise strictly to connected flame body so no isolated floating orange blobs break off
		float n_amt = (n1 * 0.62 + n2v * 0.38 - 0.48) * (0.28 + 0.38 * y) * smoothstep(0.02, 0.38, body);
		float d = body * (1.06 - y * 0.92) + n_amt;
		float a = smoothstep(0.05, 0.34, d) * edge_fade;
		vec3 base_c = vec3(2.25, 2.25, 2.25) * u_col;
		vec3 col = base_c * mix(vec3(1.0, 0.22, 0.02), vec3(1.0, 0.54, 0.09), smoothstep(0.16, 0.38, d));
		col = mix(col, base_c * vec3(1.0, 0.85, 0.38), smoothstep(0.40, 0.62, d));
		col = mix(col, base_c * vec3(1.18, 1.06, 0.82), smoothstep(0.66, 0.84, d));
		// Built-in soft radial fire glow eliminates flat-card feel on all torches & braziers
		float aura = pow(max(0.0, 1.0 - length(vec2(p.x * 1.15, (p.y + 0.22) * 1.05))), 2.8) * 0.36;
		vec3 glow_c = vec3(1.35, 0.52, 0.10) * aura;
		ALBEDO = (col * a + glow_c) * v_int;
		ALPHA = clamp((a + aura * 0.7) * v_int, 0.0, 1.0);
	}
}
