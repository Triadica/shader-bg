// Floating Bubbles effect
// Created by inigo quilez - iq/2013
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
// License.
// Forked from https://www.shadertoy.com/view/MtByRD

#include <metal_stdlib>
using namespace metal;

struct FloatingBubblesData {
  float time;
  float2 resolution;
  float2 padding;
};

static float4 floating_bubbles_effect(float2 fragCoord, float time,
                                      float2 resolution) {
  // 减慢动画速度到 1/2
  float t = time * 0.5;

  float2 uv = -1.0 + 2.0 * fragCoord.xy / resolution.xy;
  uv.x *= resolution.x / resolution.y;
  float2 ms = float2(0.5, 0.5); // 固定鼠标位置（无鼠标交互）

  // background
  float3 color = float3(0.9 + 0.1 * uv.y);

  // bubbles
  for (int i = 0; i < 40; i++) {
    // bubble seeds
    float pha = sin(float(i) * 546.13 + 1.0) * 0.5 + 0.5;
    float siz = pow(sin(float(i) * 651.74 + 5.0) * 0.5 + 0.5, 4.0);
    float pox = sin(float(i) * 321.55 + 4.1) * resolution.x / resolution.y;

    // bubble size, position and color
    float rad = 0.2 + 0.5 * siz;
    float2 pos =
        float2(pox, -1.0 - rad +
                        (2.0 + 2.0 * rad) *
                            fmod(pha + 0.1 * t * (0.1 + 0.1 * siz), 1.0));
    float distToMs = length(pos - ms);
    pos *= length(pos - (ms * 1.5 - 0.5));
    float dis = length(uv - pos);

    float3 col = mix(float3(0.34, 0.6, 0.0), float3(0.1, 0.4, 0.8),
                     0.5 + 0.5 * sin(float(i) * 1.2 + 1.9));

    // render
    float f = length(uv - pos) / rad;
    f = sqrt(clamp(1.0 - f * f, 0.0, 1.0));
    color -= col.zyx * (1.0 - smoothstep(rad * 0.95, rad, dis)) * f;
  }

  // vignetting
  color *= sqrt(1.5 - 0.5 * length(uv));

  return float4(color, 1.0);
}

kernel void floatingBubblesCompute(texture2d<float, access::write> output
                                   [[texture(0)]],
                                   constant FloatingBubblesData &data
                                   [[buffer(0)]],
                                   uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  // 翻转 Y 坐标以匹配 GLSL 的坐标系（Y 轴向上）
  float2 fragCoord = float2(gid.x, resolution.y - gid.y);

  float4 col = floating_bubbles_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
