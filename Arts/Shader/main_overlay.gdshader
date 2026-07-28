shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture
	: hint_screen_texture,
	repeat_disable,
	filter_nearest;


// ============================================================================
// 1. 总体调色
// ============================================================================

// 整体亮度倍率。
// 1.0 = 不变；低于 1 变暗；高于 1 变亮。
uniform float brightness
	: hint_range(0.5, 1.5, 0.005) = 0.9;

// 围绕中灰值 0.5 拉伸明暗差。
// 1.0 = 不变；更高会让亮部更亮、暗部更暗。
uniform float contrast
	: hint_range(0.5, 1.8, 0.005) = 1.025;

// 饱和度。
// 0 = 黑白；1 = 原色；大于 1 会增强颜色。
uniform float saturation
	: hint_range(0.0, 1.5, 0.01) = 0.8;

// 乘法色调。默认是非常浅的冷灰绿色。
// 单独改变颜色不会生效，需配合 screen_tint_strength。
uniform vec4 screen_tint
	: source_color = vec4(0.92, 1.0, 0.94, 1.0);

// 色调混合强度。
// 0 = 不调色；值越高，screen_tint 的影响越明显。
uniform float screen_tint_strength
	: hint_range(0.0, 0.5, 0.005) = 0.035;


// ============================================================================
// 2. 扫描线
// ============================================================================

// 相邻扫描线的间隔，单位是最终输出像素。
// 2~4 通常适合 720p/1080p；数值越大，条纹越稀。
uniform float scanline_spacing_px
	: hint_range(1.0, 12.0, 0.25) = 3.0;

// 扫描线压暗强度。
// 0 = 关闭；过高会切碎小字号文字和 1px 细线。
uniform float scanline_intensity
	: hint_range(0.0, 0.5, 0.005) = 0.075;

// 扫描线形状锐度。
// 低值较柔；高值更窄、更硬、更接近离散暗线。
uniform float scanline_sharpness
	: hint_range(0.25, 12.0, 0.1) = 2.2;


// ============================================================================
// 3. 屏幕颗粒
// ============================================================================

// 单色噪点强度。
// 0 = 关闭；0.01~0.04 通常足够。
uniform float grain_intensity
	: hint_range(0.0, 0.25, 0.0025) = 0.022;

// 噪点变化速度。
// 0 = 静止颗粒；更高会像快速刷新的电子噪声。
uniform float grain_speed
	: hint_range(0.0, 90.0, 0.5) = 18.0;

// 噪点向暗部集中的程度。
// 0 = 全画面同等噪点；1 = 主要出现在暗部。
uniform float grain_shadow_bias
	: hint_range(0.0, 1.0, 0.01) = 0.65;


// ============================================================================
// 4. 高亮 UI 保护
// ============================================================================

// 降低扫描线、颗粒、滚动亮度带对高亮区域的影响。
// 0 = 不保护；1 = 最大保护。适合保护白字、白线和高亮图标。
uniform float bright_protection
	: hint_range(0.0, 1.0, 0.01) = 0.55;

// 从哪个亮度开始应用高亮保护。
// 越低，更多中间色也会被保护；越高，只保护接近纯白的区域。
uniform float bright_protection_start
	: hint_range(0.0, 1.0, 0.01) = 0.72;


// ============================================================================
// 5. 暗角
// ============================================================================

// 屏幕边缘压暗强度。
// 0 = 关闭；过高会丢失角落 UI。
uniform float vignette_intensity
	: hint_range(0.0, 0.8, 0.005) = 0.12;

// 暗角开始出现的位置，使用归一化半径。
// 值越低，暗角越早进入屏幕中心；越高，暗角越靠近边缘。
uniform float vignette_start
	: hint_range(0.0, 0.99, 0.01) = 0.58;

// 暗角过渡曲线。
// 低值过渡宽而柔；高值更集中在最外圈。
uniform float vignette_power
	: hint_range(0.25, 10.0, 0.1) = 2.0;


// ============================================================================
// 6. 滚动亮度带
// ============================================================================

// 一条缓慢移动的亮度带，模拟 CRT 刷新/电源波动。
// 0 = 关闭；建议保持很低。
uniform float rolling_band_intensity
	: hint_range(0.0, 0.15, 0.0025) = 0.012;

// 亮度带移动方向与速度。
// 正值向下滚动，负值向上滚动，0 = 停止。
uniform float rolling_band_speed
	: hint_range(-3.0, 3.0, 0.05) = 0.2;

// 亮度带宽度。
// 小值是一条窄带；大值会成为大范围缓慢明暗变化。
uniform float rolling_band_width
	: hint_range(0.01, 0.75, 0.01) = 0.16;


// ============================================================================
// 7. 可选空间变形
// ============================================================================

// 屏幕曲率/桶形畸变。
// 0 = 关闭。正值会使边缘产生弯曲并可能露出 border_color。
// 开启后会重新采样 UI，可能让文字和细线产生轻微位移。
uniform float barrel_distortion
	: hint_range(0.0, 0.15, 0.001) = 0.01;

// RGB 横向分离，单位是最终输出像素。
// 0 = 关闭。1 表示红蓝通道约偏移 1 个屏幕像素。
// 主菜单和文字较多时建议 0~0.25；1.0 已经非常明显。
uniform float chromatic_aberration_px
	: hint_range(0.0, 3.0, 0.05) = 1.0;

// 每一行的水平周期扭动幅度，单位是最终输出像素。
// 0 = 关闭。过高会使 UI 边缘和细线摇晃。
uniform float horizontal_warble_px
	: hint_range(0.0, 3.0, 0.05) = 0.0;

// 横向扭动的时间速度。
// 只有 horizontal_warble_px 大于 0 时才可见。
uniform float horizontal_warble_speed
	: hint_range(0.0, 8.0, 0.05) = 0.5;

// 畸变后超出屏幕采样范围的填充颜色。
uniform vec4 border_color
	: source_color = vec4(0.0, 0.0, 0.0, 1.0);


// ============================================================================
// 工具函数
// ============================================================================

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


// ============================================================================
// 主片元处理
// ============================================================================

void fragment() {
	// 所有 Godot fragment 内置变量都只在这里直接读取，
	// 避免旧版本编辑器对辅助函数作用域解析不一致。
	vec2 uv = SCREEN_UV;
	vec2 screen_pixel_size = SCREEN_PIXEL_SIZE;
	vec2 screen_size = vec2(1.0) / screen_pixel_size;
	vec2 pixel_coord = floor(FRAGCOORD.xy);

	// ------------------------------------------------------------------------
	// 屏幕曲率
	// ------------------------------------------------------------------------

	float aspect = screen_size.x / screen_size.y;

	vec2 p = uv * 2.0 - 1.0;
	p.x *= aspect;

	float radius_sq = dot(p, p);
	p *= 1.0 + barrel_distortion * radius_sq;

	p.x /= aspect;

	vec2 sample_uv = p * 0.5 + 0.5;

	// ------------------------------------------------------------------------
	// 横向扭动
	// ------------------------------------------------------------------------

	float warble = sin(
		sample_uv.y * 19.0
		+ TIME * horizontal_warble_speed
	) * horizontal_warble_px;

	sample_uv.x += warble * screen_pixel_size.x;

	// 记录畸变后的坐标是否仍在屏幕内。
	float in_bounds =
		step(0.0, sample_uv.x)
		* step(sample_uv.x, 1.0)
		* step(0.0, sample_uv.y)
		* step(sample_uv.y, 1.0);

	vec2 safe_sample_uv = clamp(
		sample_uv,
		vec2(0.0),
		vec2(1.0)
	);

	// ------------------------------------------------------------------------
	// 色差采样
	// ------------------------------------------------------------------------

	vec2 aberration_offset = vec2(
		chromatic_aberration_px * screen_pixel_size.x,
		0.0
	);

	vec2 red_uv = clamp(
		safe_sample_uv + aberration_offset,
		vec2(0.0),
		vec2(1.0)
	);

	vec2 blue_uv = clamp(
		safe_sample_uv - aberration_offset,
		vec2(0.0),
		vec2(1.0)
	);

	vec3 color;
	color.r = texture(screen_texture, red_uv).r;
	color.g = texture(screen_texture, safe_sample_uv).g;
	color.b = texture(screen_texture, blue_uv).b;

	// 使用后处理前的亮度生成保护遮罩。
	float source_luma = dot(
		color,
		vec3(0.299, 0.587, 0.114)
	);

	// ------------------------------------------------------------------------
	// 总体调色
	// ------------------------------------------------------------------------

	color = mix(
		vec3(source_luma),
		color,
		saturation
	);

	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	color *= brightness;

	color = mix(
		color,
		color * screen_tint.rgb,
		screen_tint_strength
	);

	// ------------------------------------------------------------------------
	// 高亮保护
	// ------------------------------------------------------------------------

	float bright_mask = smoothstep(
		bright_protection_start,
		1.0,
		source_luma
	);

	float effect_weight = clamp(
		1.0 - bright_mask * bright_protection,
		0.0,
		1.0
	);

	// ------------------------------------------------------------------------
	// 扫描线
	// ------------------------------------------------------------------------

	float safe_spacing = max(scanline_spacing_px, 1.0);

	float scan_phase = fract(
		pixel_coord.y / safe_spacing
	);

	float scan_wave = 0.5 + 0.5 * cos(
		scan_phase * 6.28318530718
	);

	scan_wave = pow(
		max(scan_wave, 0.0),
		scanline_sharpness
	);

	float scan_factor = 1.0
		- scan_wave
		* scanline_intensity
		* effect_weight;

	color *= scan_factor;

	// ------------------------------------------------------------------------
	// 颗粒
	// ------------------------------------------------------------------------

	float grain_frame = floor(
		TIME * grain_speed
	);

	float grain_noise = hash21(
		pixel_coord
		+ vec2(
			grain_frame,
			grain_frame * 1.37
		)
	);

	grain_noise = grain_noise * 2.0 - 1.0;

	float dark_weight = mix(
		1.0,
		1.0 - clamp(source_luma, 0.0, 1.0),
		grain_shadow_bias
	);

	color += vec3(
		grain_noise
		* grain_intensity
		* dark_weight
		* effect_weight
	);

	// ------------------------------------------------------------------------
	// 滚动亮度带
	// ------------------------------------------------------------------------

	float band_center = fract(
		TIME * rolling_band_speed
	);

	float band_distance = abs(
		uv.y - band_center
	);

	band_distance = min(
		band_distance,
		1.0 - band_distance
	);

	float safe_band_width = max(
		rolling_band_width,
		0.0001
	);

	float band = 1.0 - smoothstep(
		0.0,
		safe_band_width,
		band_distance
	);

	color *= 1.0
		+ band
		* rolling_band_intensity
		* effect_weight;

	// ------------------------------------------------------------------------
	// 暗角
	// ------------------------------------------------------------------------

	vec2 centered_uv = uv - vec2(0.5);
	centered_uv.x *= aspect;

	float maximum_radius = length(
		vec2(0.5 * aspect, 0.5)
	);

	float normalized_radius =
		length(centered_uv)
		/ max(maximum_radius, 0.0001);

	float vignette = smoothstep(
		vignette_start,
		1.0,
		normalized_radius
	);

	vignette = pow(
		max(vignette, 0.0),
		vignette_power
	);

	color *= 1.0
		- vignette
		* vignette_intensity;

	// ------------------------------------------------------------------------
	// 最终输出
	// ------------------------------------------------------------------------

	vec4 processed_color = vec4(
		clamp(color, 0.0, 1.0),
		1.0
	);

	// fragment() 不使用提前 return。
	// 坐标越界时显示 border_color，否则显示处理后的画面。
	COLOR = mix(
		border_color,
		processed_color,
		in_bounds
	);
}
