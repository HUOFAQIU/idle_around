shader_type canvas_item;

// Cinderwatch miniature post-processing:
// Sub-texel crisp upscaling + tilt-shift DoF + ACES Filmic + vignette + 8x8 Bayer ordered dither + film grain
uniform vec2 u_tex_size = vec2(960.0, 540.0);
uniform vec2 u_out_size = vec2(1920.0, 1080.0);
uniform vec2 u_sub = vec2(0.0, 0.0);
uniform vec2 u_dither_ofs = vec2(0.0, 0.0);
uniform vec4 u_grade = vec4(1.0, 0.92, 0.55, 1.0); // x=exposure, y=saturation, z=vignette, w=fade
uniform vec3 u_lift = vec3(0.010, 0.016, 0.030);
uniform float u_dither_levels = 28.0;
uniform float u_grain = 0.035;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

float bayer8(vec2 a) {
	return bayer4(0.5 * a) * 0.25 + bayer2(a);
}

vec3 filmic(vec3 x) {
	x = max(x, vec3(0.0));
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

vec2 crisp_uv(vec2 uv) {
	vec2 texel = uv * u_tex_size + u_sub;
	vec2 scale = max(u_out_size / max(u_tex_size, vec2(1.0)), vec2(1.0));
	vec2 tf = floor(texel);
	vec2 f = texel - tf;
	vec2 region = 0.5 - 0.5 / scale;
	vec2 cen = f - 0.5;
	vec2 off = (cen - clamp(cen, -region, region)) * scale + 0.5;
	return (tf + off) / u_tex_size;
}

void fragment() {
	vec3 c = texture(TEXTURE, crisp_uv(UV)).rgb;

	// Depth-aware tilt-shift DoF now runs in atmo_dof.gdshader inside SubViewport

	// Exposure & Vignette
	c *= u_grade.x;
	vec2 q = (UV - 0.5) * vec2(1.0, 0.92);
	float vig = smoothstep(0.92, 0.30, length(q) * 1.25);
	c *= mix(1.0 - u_grade.z, 1.0, vig);

	// ACES Filmic tonemap + saturation + shadow lift
	c = filmic(c);
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(luma), c, u_grade.y);
	c += u_lift * (1.0 - smoothstep(0.0, 0.3, luma)) * mix(0.55, 1.0, vig);
	c = pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)) * u_grade.w;

	// 8x8 Bayer ordered dithering snapped to low-res texel space
	vec2 low_coord = floor(UV * u_tex_size + u_sub);
	float b = bayer8(low_coord + u_dither_ofs);
	c = floor(c * u_dither_levels + b) / u_dither_levels;

	// Subtle film grain
	float g = hash12(FRAGCOORD.xy + vec2(fract(TIME * 13.7) * 97.0, fract(TIME * 7.3) * 53.0)) - 0.5;
	c += g * u_grain * (0.35 + 0.65 * (1.0 - dot(c, vec3(0.333))));

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
