shader_type canvas_item;
// 魂灵扫描线：一条发光带自下而上扫过 —— 扫到顶就是这颗魂灵的冷却走完。
//
// progress 由战斗侧每帧推（0 = 刚触发、线在底部；1 = 冷却走完、线在顶部）。
// 为什么不学以前那样用内置 TIME 自己走：TIME 不受 Engine.time_scale 影响，
// 而冷却受 —— 一开加速，线和冷却就分家了。
//
// 不在战斗时 enable = 0，整条线不画。
//
// 光带自己有颜色也有透明度，所以**图案透明的地方一样画得出来**：
// 扫过的是整个物品格子，不只是图案的实体部分。

// 光带颜色
uniform vec4 line_color : source_color = vec4(0.54902, 0.85098, 1.0, 1.0);
// 光带半宽（占物品高度的比例），越大越柔
uniform float band_width : hint_range(0.01, 0.5) = 0.16;
// 光带强度：既是染上去的比例，也是它在透明区上的不透明度
uniform float intensity : hint_range(0.0, 1.0) = 0.85;
// 开关：0 = 整条光带不画。代码里用 ItemData.set_scanline_enabled() 控制
uniform float enable : hint_range(0.0, 1.0) = 0.0;
// 冷却进度 0..1，由战斗侧每帧写
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// UV.y 是"从上往下"的，所以底部是 1、顶部是 0 —— 进度 0 要落在底部，
	// 位置就得反过来写
	float line_y = 1.0 - clamp(progress, 0.0, 1.0);
	float d = abs(UV.y - line_y);

	// 一圈软的 + 一条硬的芯。芯要收得比外面窄，才像"一条线"而不是一道晕。
	// 注意写成 1.0 - smoothstep(0, w, d)：GLSL 规定 edge0 >= edge1 时结果未定义，
	// 虽然实际显卡都能跑，但这里不赌它
	float glow = 1.0 - smoothstep(0.0, band_width, d);
	float core = 1.0 - smoothstep(0.0, band_width * 0.3, d);
	float a = clamp((glow * 0.3 + core * 0.7) * intensity * enable, 0.0, 1.0);

	// 把光带当成"一层纯线色的膜"叠在图案上：膜的 alpha = a，颜色只有 line_color。
	// 这里必须用标准的 over 合成，不能图省事写 mix(COLOR.rgb, line_color.rgb, a) ——
	// mix 会把底下那个像素的颜色按比例掺进输出，而图案的透明/半透明区域里
	// 存着画笔自己的颜色（抗锯齿边、阴影），一掺就把图案的轮廓显出来了。
	//
	// over：out = 膜 over 底
	float a1 = COLOR.a;
	float out_a = a + a1 * (1.0 - a);
	COLOR.rgb = (line_color.rgb * a + COLOR.rgb * a1 * (1.0 - a)) / max(out_a, 0.0001);
	COLOR.a = out_a;
}
