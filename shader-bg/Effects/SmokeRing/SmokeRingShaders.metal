//
//  SmokeRingShaders.metal
//  shader-bg
//
//  Created on 2025-11-07.
//
//  Forked from https://www.shadertoy.com/view/4dVXDt

#include <metal_stdlib>
using namespace metal;

struct SmokeRingParams {
  float time;
  float2 resolution;
  int padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// Vertex shader - 全屏三角形
vertex VertexOut smokeRingVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;

  // 创建覆盖整个屏幕的大三角形
  float2 pos = float2((vertexID << 1) & 2, vertexID & 2);
  out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
  out.texCoord = pos;

  return out;
}

// 常量定义
constant float falloffPower = 0.3;
constant float radius = 0.20; // 缩小环的半径
constant float2 noiseSampleDirection = float2(1.0, 0.319);
constant int RING_COUNT = 10; // 减少环的数量以降低 GPU 开销

// 波形函数
static float srWaves(float2 coord, float2 coordMul1, float2 coordMul2,
                     float2 phases, float2 timeMuls, float iTime) {
  return 0.5 * (sin(dot(coord, coordMul1) + timeMuls.x * iTime + phases.x) +
                cos(dot(coord, coordMul2) + timeMuls.y * iTime + phases.y));
}

// 环形乘数计算（简化版，减少噪声采样）
static float srRingMultiplier(float2 coord, float distortAmount, float phase,
                              float baseXOffset, float iTime,
                              texture2d<float> noiseTexture,
                              sampler textureSampler) {
  float halfWidth = pow(0.03, falloffPower);

  // 只使用一次噪声采样
  float2 sampleLocation = noiseSampleDirection * phase;
  float3 noise = noiseTexture.sample(textureSampler, sampleLocation).rgb;

  // 简化波形计算，只用一个简单的正弦函数
  float distortX =
      baseXOffset +
      0.6 * sin(dot(coord, float2(2.0 + noise.r, 2.0 + noise.g)) * 3.0 + iTime);
  float distortY =
      0.5 + 0.7 * cos(dot(coord, float2(-2.0 - noise.g, 2.0 + noise.b)) * 3.0 +
                      iTime * 0.9);

  float amount = 0.2 + 0.3 * (abs(distortX) + abs(distortY));
  float2 distortedCoord = coord + normalize(float2(distortX, distortY)) *
                                      amount * distortAmount * 0.2;

  return smoothstep(-halfWidth, halfWidth,
                    pow(abs(length(distortedCoord) - radius), falloffPower));
}

// Fragment shader
fragment float4 smokeRingFragment(VertexOut in [[stage_in]],
                                  constant SmokeRingParams &params
                                  [[buffer(0)]],
                                  texture2d<float> noiseTexture
                                  [[texture(0)]]) {
  constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

  float2 fragCoord = in.texCoord * params.resolution;
  float2 iResolution = params.resolution;
  float iTime = params.time;

  // 计算 UV 坐标
  float2 uv = float2(0.5) - fragCoord / iResolution;
  uv.x *= iResolution.x / iResolution.y;

  // 从黑色背景开始
  float3 accumulatedColor = float3(0.0);

  // 浅色渐变（用于环的颜色），随时间变化
  float timeColor = iTime * 0.1;
  float3 tint1 =
      float3(0.6 + 0.2 * sin(timeColor), 0.7 + 0.2 * cos(timeColor * 1.3),
             0.8 + 0.2 * sin(timeColor * 0.7));
  float3 tint2 =
      float3(0.7 + 0.2 * cos(timeColor * 0.9), 0.6 + 0.2 * sin(timeColor * 1.1),
             0.8 + 0.2 * cos(timeColor * 0.8));

  float baseXOffset =
      0.5 * (0.6 * cos(iTime * 0.3 + 1.1) + 0.4 * cos(iTime * 1.2));

  // 渲染所有环
  for (int i = 0; i < RING_COUNT; i++) {
    float ringsFraction = float(i) / float(RING_COUNT);
    float amount =
        srRingMultiplier(uv, 0.1 + pow(ringsFraction, 3.0) * 0.7,
                         pow(1.0 - ringsFraction, 0.3) * 0.09 + iTime * 0.02,
                         baseXOffset, iTime, noiseTexture, textureSampler);

    // 从黑色背景叠加浅色的环
    // amount 接近 0 时是环（应该显示浅色），接近 1 时是背景（保持黑色）
    float3 lightTint = mix(tint1, tint2, pow(ringsFraction, 3.0));
    // 环(amount≈0)显示浅色，背景(amount≈1)保持黑色
    float ringIntensity = 1.0 - pow(amount, 2.0);
    accumulatedColor += lightTint * ringIntensity * 0.3;
  }

  return float4(accumulatedColor, 1.0);
}
