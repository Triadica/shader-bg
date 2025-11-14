//
//  PetalSphereShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//  Forked from https://www.shadertoy.com/view/M3VSWy

#include <metal_stdlib>
using namespace metal;

struct PetalSphereParams {
  float time;
  float2 resolution;
  float2 padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器 - 使用全屏三角形技术
vertex VertexOut petalSphereVertex(uint vertexID [[vertex_id]]) {
  // 使用单个大三角形覆盖整个屏幕，比两个三角形更高效
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// 2D 旋转矩阵辅助函数
float2x2 petalSphere_rotate2D(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return float2x2(c, -s, s, c);
}

// 片段着色器
fragment float4 petalSphereFragment(VertexOut in [[stage_in]],
                                    constant PetalSphereParams &params
                                    [[buffer(0)]]) {
  float2 fragCoord = in.uv * params.resolution;
  float2 uv = (fragCoord - 0.5 * params.resolution) / params.resolution.y;

  // 将圆形区域缩小到屏幕的 2/3，即放大 uv 坐标 1.5 倍 (3/2)
  uv *= 1.5;

  float t = params.time * 0.2;

  // 整体旋转
  float overallRotation = t * 1.3;
  float2x2 overallRot = petalSphere_rotate2D(overallRotation);
  uv = overallRot * uv;

  // 缩放动画
  float zoom = 1.0 + sin(t * 0.2) * 0.1;
  uv *= zoom;

  // 径向变形
  float z = 1.21 / (length(uv) + 0.1);
  uv *= z;

  // 旋转动画
  float angle = t * 0.5;
  float2x2 rot = petalSphere_rotate2D(angle);
  uv = rot * uv;

  // 球面映射
  float phi = atan2(uv.y, uv.x);
  float theta = acos(length(uv));
  float3 sphericalUV =
      float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));

  // 主渲染循环
  float3 O = float3(0.0);
  for (float i = 0.0; i < 6.0; i += 1.0) {
    float l = length(float2(cos(i + t), sin(i - t)) + sphericalUV.xy);
    O +=
        pow(0.09 /
                abs(sin(exp(sin(l) * 1.0 - length(sphericalUV.xy * 0.4)) * 8.0 +
                        t * 4.0) -
                    smoothstep(0.0, 0.4, l - 0.4) * 1.5) /
                smoothstep(0.0, 0.09, abs(l - 0.1)),
            1.0) *
        (1.0 + cos(i * 0.55 + l * 2.0 - t * 4.0 + float3(0.0, 1.0, 2.0)));
  }

  // 中心遮罩
  float centerMask = smoothstep(0.0, 0.01, length(uv));
  O *= centerMask;

  // 边缘淡出
  O *= smoothstep(1.0, 0.2, length(uv) * 0.7);

  return float4(O, 1.0);
}
