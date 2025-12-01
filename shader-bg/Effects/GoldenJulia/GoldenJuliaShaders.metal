//
//  GoldenJuliaShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//  Based on "Golden Julia" by Stephane Cuillerdier - Aiekick/2014
//  Forked from https://www.shadertoy.com/view/XtfGzN

#include <metal_stdlib>
using namespace metal;

// 降低迭代次数以提升性能（从 150 降到 60）
#define Iterations 60

struct GoldenJuliaParams {
  float time;
  float2 resolution;
  float2 mouse;
  float mousePressed;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器
vertex VertexOut goldenJuliaVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// 金属线条效果
float goldenJulia_metaline(float2 p, float2 o, float thick, float2 l) {
  float2 po = 2.0 * p + o;
  return thick / dot(po, float2(l.x, l.y));
}

// 优化的朱利亚集计算 - 简化逻辑以提升性能
float goldenJulia_getJulia(float2 coord, int iter, float time, float seuilInf,
                           float seuilSup) {
  float2 uvt = coord;
  float lX = -0.78;
  float lY = time * 0.115;
  float julia = 0.0;

  for (int i = 0; i < iter; i++) {
    float x = (uvt.x * uvt.x - uvt.y * uvt.y) + lX;
    float y = (uvt.y * uvt.x + uvt.x * uvt.y) + lY;
    uvt = float2(x, y);

    // 简化计算，避免不必要的 mix
    float xy = x * y;
    if (xy != 0.0) { // 避免除以零
      float j = length(uvt) / xy;
      if (j >= seuilInf && j <= seuilSup) {
        julia = j;
      }
    }
  }

  return julia;
}

// 片段着色器
fragment float4 goldenJuliaFragment(VertexOut in [[stage_in]],
                                    constant GoldenJuliaParams &params
                                    [[buffer(0)]]) {
  // 时间变量
  float speed = 0.5;
  float t0 = params.time * speed;
  float t1 = sin(t0);
  float t2 = 0.5 * t1 + 0.5;
  float t3 = 0.5 * sin(params.time * 0.1) + 0.5;
  float zoom = 1.0;

  // UV 坐标
  float ratio = params.resolution.x / params.resolution.y;
  float2 uv = in.uv * 2.0 - 1.0;
  uv.x *= ratio;
  uv *= zoom;

  // 边框线条
  float thick = 0.3;
  float inv = 1.0;
  float bottom = goldenJulia_metaline(uv, float2(0.0, 2.0) * zoom, thick,
                                      float2(0.0, 1.0 * inv));
  float top = goldenJulia_metaline(uv, float2(0.0, -2.0) * zoom, thick,
                                   float2(0.0, -1.0 * inv));
  float left = goldenJulia_metaline(uv, float2(2.0 * ratio, 0.0) * zoom, thick,
                                    float2(1.0 * inv, 0.0));
  float right = goldenJulia_metaline(uv, float2(-2.0 * ratio, 0.0) * zoom,
                                     thick, float2(-1.0 * inv, 0.0));
  float rect = bottom + top + left + right;

  // 朱利亚集参数
  float ratioIter = 1.0;
  float ratioTime = t1;

  // 如果有鼠标输入则使用鼠标控制（这里使用自动模式）
  if (params.mousePressed > 0.0) {
    ratioIter = params.mouse.y / params.resolution.y;
    ratioTime = params.mouse.x / params.resolution.x * 2.0 - 1.0;
  }

  int nIter = Iterations; // 使用完整迭代次数（GLSL 原版不动态调整）
  float julia = goldenJulia_getJulia(uv, nIter, ratioTime, 0.2, 8.5);

  // 颜色计算
  float d0 = julia + rect;
  float d = smoothstep(d0 - 45.0, d0 + 4.0, 1.0);
  float r = mix(1.0 / d, d, 1.0);
  float g = mix(1.0 / d, d, 3.0);
  float b = mix(1.0 / d, d, 5.0);
  float3 c = float3(r, g, b);

  return float4(c, 1.0);
}
