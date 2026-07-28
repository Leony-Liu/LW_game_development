shader_type canvas_item;

// 引入屏幕纹理（从管线中截取上一道工序的画面）
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// 滤镜可调参数
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4; // 暗角强度
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.005; // 色差偏移量
uniform float scanline_count : hint_range(50.0, 1000.0) = 320.0; // 扫描线密集度
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.3; // 扫描线透明度

void fragment() {
    // 1. 获取当前像素的屏幕坐标 (0.0 到 1.0)
    vec2 uv = SCREEN_UV;
    
    // 2. 边缘色差 (Chromatic Aberration) - 模拟老旧 CRT 镜头边缘色彩分离
    // 离屏幕中心越远，色差越严重
    vec2 offset = vec2(chromatic_aberration, 0.0) * (uv.y - 0.5);
    float r = texture(screen_texture, uv + offset).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv - offset).b;
    vec3 color = vec3(r, g, b);
    
    // 3. 扫描线 (Scanlines) - 模拟显像管扫描
    // 用 sin 函数根据 Y 坐标生成明暗交替的横线
    float scanline = sin(uv.y * scanline_count * 3.14159);
    scanline = (scanline * 0.5 + 0.5) * scanline_opacity;
    // 将扫描线压暗画面
    color -= scanline * 0.1; 
    
    // 4. 晕影/暗角 (Vignette) - 让四周变暗，聚焦中心，增加压抑感
    float dist = distance(uv, vec2(0.5, 0.5));
    float vignette = smoothstep(0.8, 0.2, dist * (1.0 + vignette_intensity));
    color *= vignette;
    
    // 输出最终颜色
    COLOR = vec4(color, 1.0);
}