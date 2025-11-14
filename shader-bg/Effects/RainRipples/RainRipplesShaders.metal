// Rain Ripples - 雨滴波纹效果
// Based on: https://www.shadertoy.com/view/llj3Dz
// 多个随机分布的波纹在屏幕上扩散
// Forked from https://www.shadertoy.com/view/X3fXW7

#include <metal_stdlib>
using namespace metal;

// 参数定义
constant float RIPPLES_COUNT = 8.0; // 再减少一半
constant float RIPPLES_SCALE = 7.0; // 适中的尺度,让图案稍大
constant float RIPPLES_SPEED = 0.7;
constant float3 WaveParams = float3(20.0, 2.0, 0.5);

// hash 函数：生成伪随机数
float2 hash22(float2 p) {
  float2 result =
      sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)))) *
      43758.5453;
  return 2.0 * fract(result) - 1.0;
}

// 单个波纹的计算
float Ripple(float2 uv, float index, float scale, float time) {
  uv = fract(uv) * scale + index * 127.33;

  // 减慢动画速度到原来的 1/20 (在 1/10 基础上再减慢一半)
  float t = time * RIPPLES_SPEED * 0.05;

  float2 tile = floor(uv);
  float2 fr = fract(uv);
  float2 noise = hash22(tile);

  float CurrentTime = fract(t + noise.x);

  noise = hash22(tile + floor(t + noise.x));

  float2 WaveCentre = float2(0.5, 0.5) + noise * 0.3;

  float Dist = distance(fract(uv), WaveCentre) * (5.0 + WaveParams.z * noise.x);

  float Diff = Dist - CurrentTime;

  float ScaleDiff = 1.0 - pow(3.0 * abs(Diff * WaveParams.x), WaveParams.y);
  ScaleDiff =
      max(ScaleDiff, 1.0 - pow(abs((Dist - 1.5 * CurrentTime) * WaveParams.x),
                               WaveParams.y));

  float resolution_y = 1080.0; // 假设分辨率高度
  return smoothstep(1.5 / resolution_y, 0.0, Dist - ScaleDiff) /
         (CurrentTime * 10.0);
}

kernel void rainRipplesCompute(texture2d<float, access::write> output
                               [[texture(0)]],
                               constant float &time [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = float2(output.get_width(), output.get_height());

  // Metal 坐标系统：Y 轴翻转以匹配 GLSL
  float2 fragCoord = float2(gid.x, resolution.y - float(gid.y));

  // 归一化坐标（基于高度）
  float2 uv = fragCoord / resolution.y;

  float col = 0.0;

  // 叠加多个波纹
  for (float i = 0.0; i <= RIPPLES_COUNT; i += 1.0) {
    col += Ripple(uv, i * 0.1, RIPPLES_SCALE, time);
  }

  // 输出白色波纹
  float4 color = float4(col, col, col, 1.0);
  output.write(color, gid);
}
