// PSX 风格后处理 Shader：包含胶片颗粒、CRT 扫描线、暗角、像素化、色差与画面扭动效果。
// 使用方式通常是把它挂在覆盖整个屏幕的 ColorRect 上。

shader_type canvas_item;

// 当前屏幕画面的纹理。
// hint_screen_texture：让 Godot 自动提供屏幕内容。
// filter_linear_mipmap：使用线性过滤与 mipmap；在像素化后采样时仍可能略微柔和。
// repeat_enable：允许纹理坐标重复，不过本 Shader 最终会把坐标限制在 0~1。
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap, repeat_enable;

// -------------------- 胶片颗粒参数 --------------------

// 颗粒强度。
// 0.0：完全没有颗粒；1.0：颗粒非常明显。
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.1;

// 颗粒亮度作用范围的下限。
// 与 max_lum 一起决定颗粒更偏向出现在暗部还是全画面。
uniform float min_lum : hint_range(0.0, 1.0) = 0.0;

// 颗粒亮度作用范围的上限。
// 像素亮度接近或高于该值时，颗粒会逐渐减弱。
// 值越小，颗粒越集中在暗部；值越大，颗粒会覆盖更多中间调与亮部。
uniform float max_lum : hint_range(0.0, 1.0) = 1.0;

// 颗粒图案随时间移动的速度倍率。
// 0.0：颗粒图案基本静止；值越大，颗粒变化越快。
uniform float time_scale : hint_range(0.0, 1.0) = 0.5;

// -------------------- 普通暗角参数 --------------------

// 屏幕边缘的变暗程度。
// 0.0：不变暗；1.0：边缘可接近全黑。
uniform float vignette_darkness : hint_range(0.0, 1.0) = 0.5;

// 暗角外半径，决定暗角延伸到多远的位置。
// 值越大，暗角越靠近画面外侧、影响范围越小；值越小，暗角更早进入画面。
uniform float vignette_outer_radius : hint_range(0.1, 2.0) = 0.7;

// 暗角内半径，决定画面中央保持完整亮度的区域大小。
// 值越大，中央亮区通常越大；必须小于 outer_radius 才能形成正常过渡。
uniform float vignette_inner_radius : hint_range(0.0, 1.9) = 0.2;

// -------------------- CRT 参数 --------------------

// 水平扫描线强度。
// 0.0：无扫描线；1.0：明暗条纹非常强烈。
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.2;

// 桶形畸变强度，让屏幕中心略微凸起、边缘向外弯曲，模拟老式 CRT 屏幕。
// 0.0：无弯曲；值越大，四周弯曲与黑边越明显。
uniform float barrel_distortion : hint_range(0.0, 0.5) = 0.15;

// 色差强度，控制红色通道向右、蓝色通道向左的采样偏移量。
// 0.0：无色边；值越大，物体边缘的红蓝分离越明显。
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.005;

// CRT 二次暗角的幂指数。
// 它使用距屏幕中心的平方距离压暗边缘。
// 0.0：该层暗角不生效；值越大，边缘衰减越快、中心更突出。
uniform float crt_vignette_power : hint_range(0.0, 5.0) = 2.0;

// -------------------- 像素化与颜色量化参数 --------------------

// 模拟画面的横向逻辑分辨率。
// 值越小，横向像素块越大；值越大，画面越细腻。
uniform int pixel_resolution_x : hint_range(32, 1280) = 320;

// 模拟画面的纵向逻辑分辨率。
// 值越小，纵向像素块越大；值越大，画面越细腻。
uniform int pixel_resolution_y : hint_range(24, 960) = 240;

// 是否启用颜色量化。
// true：减少可用颜色层级，产生复古色带；false：保留原始颜色渐变。
uniform bool enable_color_quantization = true;

// 每个 RGB 通道保留的颜色阶数。
// 值越小，颜色层级越少、色带和复古感越强；值越大，颜色越平滑。
uniform float color_quant_steps : hint_range(2.0, 64.0) = 32.0;

// -------------------- 画面扭动参数 --------------------

// 扭动位移的最大幅度，单位是 UV 坐标。
// 0.0：不扭动；值越大，画面波动和抖动越明显。
uniform float warble_amount : hint_range(0.0, 0.01) = 0.002;

// 扭动动画速度。
// 0.0：扭动形状静止；值越大，波动变化越快。
uniform float warble_speed : hint_range(0.0, 10.0) = 5.0;


// 根据二维坐标 p 生成一个 -1~1 左右的伪随机值。
// p：噪声采样位置；同一个位置始终得到相同结果。
float noise(vec2 p) {
    // dot(...) 把二维坐标组合成一个数；sin、fract 和大常数共同制造伪随机分布。
    return (fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 2.0;
}

// 柔光混合函数，用颗粒层 B 调整原图 A。
// A：底图颜色；B：混合层颜色。
vec3 soft_light(vec3 A, vec3 B) {
    // 当混合层 B 小于 0.5 时使用的柔光公式，整体偏向压暗。
    vec3 branch1 = 2.0 * A * B + A * A * (1.0 - 2.0 * B);

    // 当混合层 B 大于等于 0.5 时使用的柔光公式，整体偏向提亮。
    vec3 branch2 = 2.0 * A * (1.0 - B) + sqrt(A) * (2.0 * B - 1.0);

    // 每个 RGB 通道分别判断 B 是否达到 0.5：小于时为 0，大于等于时为 1。
    vec3 condition = step(0.5, B);

    // 根据 condition 在 branch1 与 branch2 之间逐通道选择。
    return mix(branch1, branch2, condition);
}

// 把连续颜色压缩为有限的颜色阶数。
// color：输入 RGB；steps：每个通道的离散层级数。
vec3 quantize_color(vec3 color, float steps) {
    return floor(color * steps) / steps;
}


void fragment() {
    // 当前屏幕像素的标准化坐标，左上/左下到右下的范围通常为 0~1。
    vec2 uv = SCREEN_UV;

    // 屏幕实际像素尺寸，例如 1920×1080。
    // SCREEN_PIXEL_SIZE 是单个像素对应的 UV 大小，所以取倒数得到分辨率。
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

    // 把连续 UV 坐标吸附到指定的逻辑分辨率网格，实现像素化。
    // pixel_uv 在每个逻辑像素块内部保持相同，因此采样结果呈现大像素块。
    vec2 pixel_uv = floor(uv * vec2(float(pixel_resolution_x), float(pixel_resolution_y)))
                  / vec2(float(pixel_resolution_x), float(pixel_resolution_y));

    // 把坐标中心从 0.5,0.5 移到 0,0，便于计算距屏幕中心的位置。
    vec2 center_uv = pixel_uv - 0.5;

    // 到中心距离的平方，用于桶形畸变和 CRT 暗角。
    // 不开平方可以减少计算量，并产生适合当前公式的非线性变化。
    float r2 = dot(center_uv, center_uv);

    // 根据距中心距离放大坐标：越靠边，放大越多，从而产生桶形弯曲。
    vec2 distorted_uv = center_uv * (1.0 + barrel_distortion * r2);

    // 把以 0,0 为中心的坐标移回 0~1 范围。
    distorted_uv += 0.5;

    // 桶形畸变后超出屏幕的区域直接显示为黑色，形成 CRT 弯曲边缘。
    if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 || distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        // 随时间和屏幕位置变化的二维扭动偏移。
        // x、y 使用不同频率的正弦/余弦组合，避免形成过于规则的单一波纹。
        vec2 warble_offset = vec2(
            sin(TIME * warble_speed + uv.x * 10.0) * cos(TIME * warble_speed * 0.7 + uv.y * 7.0),
            cos(TIME * warble_speed * 0.8 + uv.y * 11.0) * sin(TIME * warble_speed * 0.9 + uv.x * 8.0)
        ) * warble_amount;

        // 最终用于读取屏幕纹理的 UV：桶形畸变坐标 + 动态扭动偏移。
        vec2 final_sample_uv = distorted_uv + warble_offset;

        // 防止扭动后采样超出屏幕范围。
        final_sample_uv = clamp(final_sample_uv, vec2(0.0), vec2(1.0));

        // 保存经过色差、并可能经过颜色量化后的基础画面颜色。
        vec3 original_color;

        // 暂存色差采样后的 RGB。
        vec3 col;

        // 红色通道向右偏移采样。
        col.r = texture(SCREEN_TEXTURE, final_sample_uv + vec2(chromatic_aberration, 0.0)).r;

        // 绿色通道保持在原位置采样，作为色差中心。
        col.g = texture(SCREEN_TEXTURE, final_sample_uv).g;

        // 蓝色通道向左偏移采样。
        col.b = texture(SCREEN_TEXTURE, final_sample_uv - vec2(chromatic_aberration, 0.0)).b;

        // 合并三个偏移采样通道，得到带红蓝色边的画面。
        original_color = col;

        // 可选的颜色阶数量化。
        if (enable_color_quantization) {
            original_color = quantize_color(original_color, color_quant_steps);
        }

        // 计算感知亮度：绿色权重最大，蓝色权重最小。
        float lum = dot(original_color, vec3(0.299, 0.587, 0.114));

        // 根据亮度计算颗粒权重。
        // 暗部 factor 接近 1，亮部 factor 接近 0，因此颗粒主要作用于暗部。
        float factor = 1.0 - smoothstep(min_lum, max_lum, lum);

        // 让噪声采样位置随时间移动，避免颗粒图案固定在屏幕上。
        // 20.0 决定移动距离；time_scale 决定移动速度。
        vec2 offset = vec2(sin(TIME * time_scale), cos(TIME * time_scale)) * 20.0;

        // 当前像素的噪声采样坐标。
        vec2 noise_uv = uv + offset;

        // 分别给 RGB 通道采样略有偏移的噪声，制造彩色颗粒，而不是灰度颗粒。
        float noise_r = noise(noise_uv);
        float noise_g = noise(noise_uv + vec2(0.1, 0.2));
        float noise_b = noise(noise_uv + vec2(0.3, 0.4));

        // 最终颗粒向量：随机值 × 用户强度 × 暗部权重。
        vec3 grain = vec3(noise_r, noise_g, noise_b) * grain_intensity * factor;

        // 把颗粒围绕中性灰 0.5 分布，并限制在合法颜色范围内。
        // 0.5 在柔光混合中基本不改变原图；高于/低于 0.5 分别提亮/压暗。
        vec3 grain_color = clamp(vec3(0.5) + grain, 0.0, 1.0);

        // 把颗粒层以柔光方式叠加到原画面。
        vec3 processed_color = soft_light(original_color, grain_color);

        // 屏幕宽高比，用于修正普通暗角的形状，避免宽屏下暗角变成椭圆。
        float aspect_ratio = screen_size.x / screen_size.y;

        // 把原始 UV 坐标中心移到 0,0。
        vec2 adjusted_uv = uv - 0.5;

        // 按宽高比拉伸 x 轴，使距离计算更接近圆形暗角。
        adjusted_uv.x *= aspect_ratio;

        // 防止 inner_radius 大于等于 outer_radius，并至少保留 0.01 的过渡宽度。
        float inner_rad = min(vignette_inner_radius, vignette_outer_radius - 0.01);

        // 当前像素到屏幕中心的修正后距离。
        float dist = length(adjusted_uv);

        // 暗角过渡比例：中心趋近 1，外侧趋近 0。
        // 注意：这里把 smoothstep 的两个边界反向传入。许多 GPU 上能得到反向过渡，
        // 但 GLSL 规范中 edge0 >= edge1 的结果未严格定义。更稳妥的等价写法是：
        // float vignette_pct = 1.0 - smoothstep(inner_rad, vignette_outer_radius, dist);
        float vignette_pct = smoothstep(vignette_outer_radius, inner_rad, dist);

        // 把暗角比例转换为亮度倍率。
        // 中心约为 1.0；边缘最低约为 1.0 - vignette_darkness。
        float vignette_factor = mix(1.0 - vignette_darkness, 1.0, vignette_pct);

        // 应用普通暗角。
        processed_color *= vignette_factor;

        // 根据实际屏幕纵向像素位置生成周期性扫描线。
        // 乘以 3.0 会让条纹周期更密，形成明暗交替的水平线。
        float scanline_alpha = sin(uv.y * screen_size.y * 3.0);

        // 把 sin 的 -1~1 转换并限制为 0~1。
        scanline_alpha = clamp(scanline_alpha * 0.5 + 0.5, 0.0, 1.0);

        // 根据 scanline_intensity 把扫描线转换为亮度倍率。
        // 强度为 0 时倍率恒为 1；强度越高，暗线越暗。
        scanline_alpha = 1.0 - (scanline_alpha * scanline_intensity);

        // 应用扫描线。
        processed_color *= scanline_alpha;

        // 第二层 CRT 中心暗角。
        // r2 越大越靠近边缘，1-r2 越小；power 越大，边缘衰减越明显。
        float crt_vignette = pow(1.0 - r2, crt_vignette_power);

        // 应用 CRT 暗角。
        processed_color *= crt_vignette;

        // 输出最终 RGB，Alpha 固定为完全不透明。
        COLOR = vec4(processed_color, 1.0);
    }
}
