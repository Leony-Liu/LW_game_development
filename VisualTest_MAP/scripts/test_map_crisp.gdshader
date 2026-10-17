shader_type canvas_item;

// 屏幕纹理必须保持最近邻采样，避免后处理阶段再次做双线性插值。
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// ==========================================
// 1. 基础色彩
// ==========================================
uniform float color_depth : hint_range(2.0, 256.0, 1.0) = 12.0;
uniform float contrast : hint_range(0.5, 2.0, 0.05) = 1.1;
uniform float brightness : hint_range(0.5, 2.0, 0.05) = 1.0;

// ==========================================
// 2. 抖动
// ==========================================
uniform float dither_strength : hint_range(0.0, 1.0, 0.01) = 0.02;
uniform float dither_scale : hint_range(1.0, 4.0, 1.0) = 1.0;

// ==========================================
// 3. CRT 效果
// ==========================================
// 改为“纹理像素”单位，而不是 UV 单位。
// 字体模糊时先保持 0；需要色差时建议从 0.5~1.0 开始。
uniform float chromatic_aberration_px : hint_range(0.0, 3.0, 0.25) = 0.0;

// 色差只在画面外围逐渐出现，中心 UI 更清晰。
uniform float aberration_edge_start : hint_range(0.0, 0.7, 0.01) = 0.30;

uniform float scanline_intensity : hint_range(0.0, 1.0, 0.01) = 0.08;
uniform float vignette_intensity : hint_range(0.0, 2.0, 0.05) = 0.8;

// 对接近白色的高亮细节进行保护，降低白色字体被量化、抖动和色差破坏的程度。
// 这是亮度启发式，并不能真正区分 UI 与 3D 高光。
uniform float bright_detail_protection : hint_range(0.0, 1.0, 0.05) = 0.55;
uniform float bright_detail_threshold : hint_range(0.0, 1.0, 0.01) = 0.78;

const float bayer_matrix_4x4[16] = float[](
	0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

void fragment() {
	vec2 pixel_coord = FRAGCOORD.xy;
	vec4 source = texture(screen_texture, SCREEN_UV);

	// 色差偏移使用 SCREEN_PIXEL_SIZE，效果不会随分辨率任意变化。
	float distance_from_center = length(SCREEN_UV - vec2(0.5));
	float edge_mask = smoothstep(aberration_edge_start, 0.72, distance_from_center);
	vec2 aberration_offset = vec2(
		SCREEN_PIXEL_SIZE.x * chromatic_aberration_px * edge_mask,
		0.0
	);

	float r = texture(screen_texture, SCREEN_UV + aberration_offset).r;
	float g = source.g;
	float b = texture(screen_texture, SCREEN_UV - aberration_offset).b;
	vec3 processed = vec3(r, g, b);

	processed = (processed - 0.5) * contrast + 0.5;
	processed *= brightness;

	int x = int(floor(pixel_coord.x / dither_scale)) % 4;
	int y = int(floor(pixel_coord.y / dither_scale)) % 4;
	float dither = bayer_matrix_4x4[y * 4 + x] - 0.5;
	processed += dither * dither_strength;

	processed = floor(processed * color_depth + 0.5) / color_depth;

	// 固定按渲染像素生成隔行扫描线，避免连续正弦造成软化观感。
	float scanline = mod(floor(pixel_coord.y), 2.0) * scanline_intensity * 0.08;
	processed *= 1.0 - scanline;

	float vignette_distance = length(SCREEN_UV - vec2(0.5));
	float vignette = smoothstep(0.8, 0.2, vignette_distance * vignette_intensity);
	processed *= vignette;

	// 尽量把白色字体等高亮细节混回原始画面。
	float source_luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float bright_mask = smoothstep(bright_detail_threshold, 1.0, source_luma);
	processed = mix(
		processed,
		source.rgb,
		bright_mask * bright_detail_protection
	);

	COLOR = vec4(clamp(processed, vec3(0.0), vec3(1.0)), source.a);
}
