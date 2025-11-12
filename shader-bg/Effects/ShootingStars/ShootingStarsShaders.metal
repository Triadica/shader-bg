//
//  ShootingStarsShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//  Based on "Shooting Stars" by XorDev
//  Fork from https://www.shadertoy.com/view/dtjGDh
//

#include <metal_stdlib>
using namespace metal;

struct ShootingStarsParams {
  float time;
  float2 resolution;
  float2 padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器
vertex VertexOut shootingStarsVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// 片段着色器
fragment float4 shootingStarsFragment(VertexOut in [[stage_in]],
                                      constant ShootingStarsParams &params
                                      [[buffer(0)]]) {
  // 清除输出颜色
  float4 outColor = float4(0.0);

  // 归一化坐标（基于高度）
  float2 st = in.uv * params.resolution / params.resolution.y;

  // 线条尺寸（盒子）
  float2 b = float2(0.0, 0.2);

  // 旋转矩阵
  float2x2 rotation;

  float dist;
  float2 loopST;

  // 迭代 21 次（从 0.9 开始，到 20.9）
  for (float i = 0.9; i < 21.0; i += 1.0) {
    // 为每次迭代创建旋转
    // cos(i + vec4(0,33,11,0)) 近似等于 [cos(i), sin(i), -sin(i), cos(i)]
    // 33 ≈ 10.5π (相当于 0.5π)，11 ≈ 3.5π (相当于 1.5π)
    float c = cos(i);
    float s1 = cos(i + 33.0); // 近似 sin(i)
    float s2 = cos(i + 11.0); // 近似 -sin(i)
    rotation = float2x2(c, s1, s2, c);

    // 缩放底层空间
    loopST = st * i * 0.1;

    // 随时间向下平移
    loopST.y += params.time * 0.2;

    // 将点转换为旋转的正方形
    loopST = fract(loopST * rotation) - 0.5;

    // 再次旋转，使局部向下方向等于全局向下方向
    loopST = rotation * loopST;

    // 计算线内最近点与当前点之间的距离
    dist = distance(clamp(loopST, -b, b), loopST);

    // 添加颜色，带有距离衰减和彩色调色板
    outColor += 0.001 / dist * (cos(loopST.y / 0.1 + float4(0, 1, 2, 3)) + 1.0);
  }

  return outColor;
}
