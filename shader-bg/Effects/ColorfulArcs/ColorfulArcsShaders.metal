// Colorful Arcs - 彩色弧光效果
// Based on: https://www.shadertoy.com/view/lscGDr and
// https://www.shadertoy.com/view/ll2GD3 使用多个旋转光源创建彩色弧光效果
// Forked from https://www.shadertoy.com/view/XXKfWm

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define NUM_LIGHTS 7

// 梯度噪声函数 - 用于减少色带
float gradientNoise(float2 uv) {
  const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
  return fract(magic.z * fract(dot(uv, magic.xy)));
}

// 调色板函数 - 基于余弦的颜色生成
float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
  return a + b * cos(6.28318 * (c * t + d));
}

// 2D旋转矩阵
float2x2 rotate(float a) {
  float c = cos(a);
  float s = sin(a);
  return float2x2(c, -s, s, c);
}

kernel void colorfulArcsCompute(texture2d<float, access::write> output
                                [[texture(0)]],
                                constant float &time [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = float2(output.get_width(), output.get_height());
  float2 fragCoord = float2(gid);

  // 归一化坐标到 [-1, 1]
  float2 uv = fragCoord / resolution.xy;
  uv = uv * 2.0 - 1.0;
  uv.x *= resolution.x / resolution.y;

  // 缩小图案到 3/4 大小（相当于放大坐标系）
  uv *= 4.0 / 3.0;

  // 减慢动画速度到 1/4
  float t = time * 0.75 * 0.25;

  float3 finalColor = float3(0.0);
  float sumWeights = 0.0;

  // 背景色
  float3 bgColor = float3(0.75);
  float bgWeight = 0.05;
  finalColor += bgColor * bgWeight;
  sumWeights += bgWeight;

  // 渲染多个光源
  for (int i = 0; i < NUM_LIGHTS; i++) {
    float n = float(i) / float(NUM_LIGHTS);
    float wave = sin(n * PI + t) * 0.5 + 0.5;

    // 光源位置（圆周运动）
    float distance = 0.3 + wave * 0.125;
    float2 position = float2(cos(n * PI * 2.0 + t * 0.1) * distance,
                             sin(n * PI * 2.0 + t * 0.1) * distance);

    // 光源方向（带旋转）
    float2 direction = position;
    direction = rotate(1.0 + wave * 0.2) * direction;

    // 弧形遮罩
    float arcAt = 0.5;
    float2 toLight = position - uv;
    float distFragLight = length(toLight);
    distFragLight = distFragLight < arcAt ? 100.0 : distFragLight;

    // 聚光灯效果
    float lightConeAngle = 6.0;
    float lightDot =
        pow(clamp(dot(normalize(toLight), normalize(-direction)), 0.0, 1.0),
            lightConeAngle);

    // 距离衰减
    float decayRate = 3.5;
    float distanceFactor = exp(-1.0 * decayRate * distFragLight);

    // 基于波形生成颜色
    float3 color = palette(wave, float3(0.5, 0.5, 0.5), float3(0.5, 0.5, 0.5),
                           float3(1.0, 1.0, 1.0), float3(0.0, 0.10, 0.20));

    float3 lightColor = color * lightDot * distanceFactor;

    finalColor += lightColor;
    sumWeights += distanceFactor * lightDot;
  }

  // 归一化
  finalColor = finalColor / sumWeights;

  // Gamma校正
  finalColor = pow(finalColor, float3(1.0 / 2.2));

  // 添加噪声减少色带
  finalColor += (1.0 / 255.0) * gradientNoise(fragCoord) - (0.5 / 255.0);

  float4 color = float4(finalColor, 1.0);
  output.write(color, gid);
}
