//
//  RhombusShaders.metal
//  shader-bg
//
//  Created on 2025-10-29.
//  Forked https://www.shadertoy.com/view/XsBfRW

#include <metal_stdlib>
using namespace metal;

struct RhombusParams {
  float2 resolution;
  float time;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器 - 生成全屏四边形
vertex VertexOut rhombusVertex(uint vertexID [[vertex_id]]) {
  // 生成覆盖整个屏幕的三角形顶点
  // 0: (-1, -1), 1: (3, -1), 2: (-1, 3)
  // 3: (-1, -1), 4: (3, -1), 5: (-1, 3)
  float2 positions[6] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0),  float2(-1.0, -1.0),
                         float2(3.0, -1.0),  float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  // 将 [-1, 1] 转换为 [0, 1]
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// 片段着色器 - 实现 rhombus 效果
fragment float4 rhombusFragment(VertexOut in [[stage_in]],
                                constant RhombusParams &params [[buffer(0)]]) {
  float2 fragCoord = in.uv * params.resolution;
  float2 iResolution = params.resolution;
  float iTime = params.time;

  float aspect = iResolution.y / iResolution.x;
  float value;
  float2 uv = fragCoord.xy / iResolution.x;
  uv -= float2(0.5, 0.5 * aspect);

  // 旋转45度 (45度 = pi/4 弧度)
  float rot = M_PI_F / 4.0; // 45度转弧度
  float2x2 m = float2x2(cos(rot), -sin(rot), sin(rot), cos(rot));
  uv = m * uv;
  uv += float2(0.5, 0.5 * aspect);
  uv.y += 0.5 * (1.0 - aspect);

  float2 pos = 10.0 * uv;
  float2 rep = fract(pos);
  float dist = 2.0 * min(min(rep.x, 1.0 - rep.x), min(rep.y, 1.0 - rep.y));
  float squareDist = length((floor(pos) + float2(0.5)) - float2(5.0));

  float edge = sin(iTime - squareDist * 0.5) * 0.5 + 0.5;

  edge = (iTime - squareDist * 0.5) * 0.5;
  edge = 2.0 * fract(edge * 0.5);

  value = fract(dist * 2.0);
  value = mix(value, 1.0 - value, step(1.0, edge));
  edge = pow(abs(1.0 - edge), 2.0);

  value = smoothstep(edge - 0.05, edge, 0.95 * value);

  value += squareDist * 0.1;

  // 原始逻辑，但调整蓝色部分使其更深更饱和
  // 白色(value=0) 到 深蓝色(value=1)
  // 从 (0.5, 0.75, 1.0) 改为 (0.2, 0.5, 1.0) - 降低红色和绿色分量，增加饱和度
  float4 fragColor =
      mix(float4(1.0, 1.0, 1.0, 1.0), float4(0.2, 0.5, 1.0, 1.0), value);
  fragColor.a = 0.25 * clamp(value, 0.0, 1.0);

  return fragColor;
}
