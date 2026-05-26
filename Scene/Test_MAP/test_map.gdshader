shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// ==========================================
// 1. 基础色彩与光影控制 (Color & Lighting)
// ==========================================

// @description 色彩量化级别：数值越低，同屏颜色越少，色阶断层越明显，PSX 质感越强。建议值: 16~64。
uniform float color_depth : hint_range(2.0, 256.0, 1.0) = 32.0;

// @description 整体对比度：增强画面明暗反差。复古游戏通常对比度较高，显得更硬朗。
uniform float contrast : hint_range(0.5, 2.0, 0.05) = 1.1;

// @description 亮度补偿：色彩量化有时会让画面变暗，用此参数微调整体亮度。
uniform float brightness : hint_range(0.5, 2.0, 0.05) = 1.0;


// ==========================================
// 2. 抖动与噪点控制 (Dithering & Noise)
// ==========================================

// @description 抖动强度：控制色阶断层处像素交错融合的明显程度。数值越高，颗粒感越强。
uniform float dither_strength : hint_range(0.0, 1.0, 0.01) = 0.05;

// @description 抖动矩阵缩放：控制抖动像素块的大小。1.0 为原始像素级别，2.0 会让抖动颗粒变大一倍，更显粗糙。
uniform float dither_scale : hint_range(1.0, 4.0, 1.0) = 1.0;


// ==========================================
// 3. 老旧显示器模拟 (CRT Artifacts)
// ==========================================

// @description 色差强度(RGB分离)：模拟老电视电子束未对齐，在物体边缘产生的红蓝重影。对恐怖氛围加成极大。
uniform float chromatic_aberration : hint_range(0.0, 0.01, 0.0001) = 0.001;

// @description 扫描线强度：横向暗线的深度。建议不要调太高，以免影响画面阅读。
uniform float scanline_intensity : hint_range(0.0, 1.0, 0.01) = 0.15;

// @description 暗角强度：压暗屏幕四周，聚焦中心。配合手电筒光源使用效果最佳。
uniform float vignette_intensity : hint_range(0.0, 2.0, 0.05) = 0.8;


// 经典的 4x4 Bayer 抖动矩阵
const float bayer_matrix_4x4[16] = float[](
    0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
    12.0/16.0, 4.0/16.0, 14.0/16.0,  6.0/16.0,
    3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
    15.0/16.0, 7.0/16.0, 13.0/16.0,  5.0/16.0
);

void fragment() {
    vec2 uv = FRAGCOORD.xy;

    // --- 1. 色差偏移采样 (Chromatic Aberration) ---
    // 通过给红蓝通道加上微小的 UV 偏移来实现重影
    float r = texture(screen_texture, SCREEN_UV + vec2(chromatic_aberration, 0.0)).r;
    float g = texture(screen_texture, SCREEN_UV).g;
    float b = texture(screen_texture, SCREEN_UV - vec2(chromatic_aberration, 0.0)).b;
    vec3 color = vec3(r, g, b);

    // --- 2. 亮度与对比度 (Brightness & Contrast) ---
    color = (color - 0.5) * contrast + 0.5;
    color *= brightness;

    // --- 3. 矩阵抖动 (Dithering) ---
    // 加入 dither_scale 让你可以控制抖动颗粒的大小
    int x = int(uv.x / dither_scale) % 4;
    int y = int(uv.y / dither_scale) % 4;
    float dither = bayer_matrix_4x4[y * 4 + x] - 0.5;
    color += dither * dither_strength;

    // --- 4. 色彩量化 (Color Depth) ---
    color = floor(color * color_depth + 0.5) / color_depth;

    // --- 5. CRT 扫描线 (Scanlines) ---
    float scanline = sin(uv.y * 3.14159) * 0.04 * scanline_intensity;
    color -= scanline;

    // --- 6. 压抑暗角 (Vignette) ---
    vec2 center_uv = SCREEN_UV - vec2(0.5);
    float vignette = length(center_uv);
    color *= smoothstep(0.8, 0.2, vignette * vignette_intensity);

    COLOR = vec4(color, 1.0);
}