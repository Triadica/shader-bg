//
//  EventHorizonShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//  Based on "Event Horizon Telescope" black hole visualization
//  Forked from https://www.shadertoy.com/view/lfc3DH

#include <metal_stdlib>
using namespace metal;

#define PI 3.141592654

// 度数转弧度（Metal 没有 radians 函数）
#define radians(deg) ((deg) * PI / 180.0)

struct EventHorizonParams {
  float time;
  float2 resolution;
  float2 padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器
vertex VertexOut eventHorizonVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// Hash 函数用于生成伪随机纹理
float eventHorizon_hash(float2 p) {
  float h = dot(p, float2(127.1, 311.7));
  return fract(sin(h) * 43758.5453123);
}

// 生成单层噪声
float eventHorizon_noise(float2 uv) {
  float2 ip = floor(uv);
  float2 fp = fract(uv);
  fp = fp * fp * (3.0 - 2.0 * fp); // smoothstep

  float a = eventHorizon_hash(ip);
  float b = eventHorizon_hash(ip + float2(1, 0));
  float c = eventHorizon_hash(ip + float2(0, 1));
  float d = eventHorizon_hash(ip + float2(1, 1));

  return mix(mix(a, b, fp.x), mix(c, d, fp.x), fp.y);
}

// 优化的分形布朗运动（FBM）- 减少到 3 层以提升性能
float eventHorizon_fbm(float2 uv) {
  // 手动展开循环以提升性能
  float value = 0.0;
  value += 0.5 * eventHorizon_noise(uv);
  value += 0.25 * eventHorizon_noise(uv * 2.0);
  value += 0.125 * eventHorizon_noise(uv * 4.0);

  return value;
}

// 片段着色器
fragment float4 eventHorizonFragment(VertexOut in [[stage_in]],
                                     constant EventHorizonParams &params
                                     [[buffer(0)]]) {
  // 居中并归一化坐标（基于高度）
  float2 uv = (in.uv * params.resolution - 0.5 * params.resolution) /
              params.resolution.y;

  float v = 0.0;

  // 微弱的红色环
  v += 0.2 * smoothstep(0.3, 0.0, abs(length(uv) - 0.2) - 0.01);

  // 吸积盘的 4 个发光团块
  const float ao[4] = {-0.07, 0.53, -1.25, -0.65}; // 角度偏移
  const float r[4] = {0.17, 0.3, 0.3, 0.4};        // 半径
  const float f[4] = {1.2, 0.9, 0.6, 0.2};         // 强度因子

  for (int i = 0; i < 4; ++i) {
    float a =
        3.0 * radians(-30.0) * r[i] * params.time + radians(360.0) * ao[i];
    float2 pos = r[i] * float2(cos(a), sin(a));
    v += f[i] * smoothstep(1.02, 0.0, length(uv - pos) + 0.5);
  }

  // 黑色中心（黑洞阴影）
  v -= 0.35 * smoothstep(0.35, 0.1, abs(length(uv)) + 0.03);

  // 偏振效果（环状波纹）
  {
    float2 uv_polar = uv;
    uv_polar += 0.05 * sin(5.0 * uv_polar + radians(90.0));

    float a = 0.5 + atan2(uv_polar.y, uv_polar.x) / radians(360.0);
    float radius = length(uv_polar);

    float p = 20.0 * (0.5 * radians(360.0) * (a + 0.1 * params.time) +
                      radians(360.0) * (radius - 0.5) * (radius - 0.5));

    // 使用优化的 FBM 噪声模拟纹理采样，平衡细节和性能
    float2 tex_coord = float2(0.5 + 0.5 * sin(0.1 * p),
                              0.5 + 0.1 * radius + 0.007 * params.time);

    // 降低采样频率到 25.0 以提升性能，同时保持足够细节
    float noise_val = eventHorizon_fbm(tex_coord * 25.0);

    float vm = smoothstep(0.0, 0.3, radius) * smoothstep(0.5, 0.1, radius) *
               (0.5 + 100.0 * noise_val);

    v = v * (1.0 + 0.01 * vm) + 0.0 * vm;
  }

  // 颜色化（橙红色到明亮黄白色渐变）
  float3 col =
      smoothstep(float3(-0.2, 0.0, 0.45), float3(0.55, 1.0, 1.05), float3(v));

  return float4(col, 1.0);
}
