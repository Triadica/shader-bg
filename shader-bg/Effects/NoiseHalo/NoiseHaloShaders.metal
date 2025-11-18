//
//  NoiseHaloShaders.metal
//  shader-bg
//
//  Created by chen on 2025/10/28.
//
//  Forked from https://www.shadertoy.com/view/3tBGRm
//  Noise Halo effect with procedural noise and animated ring

#include <metal_stdlib>
using namespace metal;

struct NoiseHaloParams {
  float time;
  float2 resolution;
  float padding1;
  float padding2;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// 全屏三角形顶点着色器
vertex VertexOut noiseHaloVertexShader(uint vertexID [[vertex_id]],
                                       constant NoiseHaloParams &params
                                       [[buffer(0)]]) {
  VertexOut out;

  // 创建覆盖整个屏幕的三角形
  float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};

  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;

  return out;
}

// Noise functions from https://www.shadertoy.com/view/4sc3z2
float3 hash33(float3 p3) {
  p3 = fract(p3 * float3(0.1031, 0.11369, 0.13787));
  p3 += dot(p3, p3.yxz + 19.19);
  return -1.0 +
         2.0 * fract(float3(p3.x + p3.y, p3.x + p3.z, p3.y + p3.z) * p3.zyx);
}

// 完整噪声函数 - 保持视觉连续性
float snoise3(float3 p) {
  const float K1 = 0.333333333;
  const float K2 = 0.166666667;

  float3 i = floor(p + (p.x + p.y + p.z) * K1);
  float3 d0 = p - (i - (i.x + i.y + i.z) * K2);

  float3 e = step(float3(0.0), d0 - d0.yzx);
  float3 i1 = e * (1.0 - e.zxy);
  float3 i2 = 1.0 - e.zxy * (1.0 - e);

  float3 d1 = d0 - (i1 - K2);
  float3 d2 = d0 - (i2 - K1);
  float3 d3 = d0 - 0.5;

  float4 h = max(
      0.6 - float4(dot(d0, d0), dot(d1, d1), dot(d2, d2), dot(d3, d3)), 0.0);
  float4 n = h * h * h * h *
             float4(dot(d0, hash33(i)), dot(d1, hash33(i + i1)),
                    dot(d2, hash33(i + i2)), dot(d3, hash33(i + 1.0)));

  return dot(float4(31.316), n);
}

float4 extractAlpha(float3 colorIn) {
  float4 colorOut;
  float maxValue = min(max(max(colorIn.r, colorIn.g), colorIn.b), 1.0);
  if (maxValue > 1e-5) {
    colorOut.rgb = colorIn.rgb * (1.0 / maxValue);
    colorOut.a = maxValue;
  } else {
    colorOut = float4(0.0);
  }
  return colorOut;
}

float light1(float intensity, float attenuation, float dist) {
  return intensity / (1.0 + dist * attenuation);
}

float light2(float intensity, float attenuation, float dist) {
  return intensity / (1.0 + dist * dist * attenuation);
}

void draw(thread float4 &fragColor, float2 vUv, float time) {
  const float3 color1 = float3(0.611765, 0.262745, 0.996078);
  const float3 color2 = float3(0.298039, 0.760784, 0.913725);
  const float3 color3 = float3(0.062745, 0.078431, 0.600000);
  const float innerRadius = 0.6;
  const float noiseScale = 0.65;

  float2 uv = vUv;
  float ang = atan2(uv.y, uv.x);
  float len = length(uv);
  float v0, v1, v2, v3, cl;
  float r0, d0, n0;
  float d;

  // ring - 简化噪声采样
  n0 = snoise3(float3(uv * noiseScale, time * 0.5)) * 0.5 + 0.5;
  r0 = mix(mix(innerRadius, 1.0, 0.4), mix(innerRadius, 1.0, 0.6), n0);
  d0 = distance(uv, r0 / len * uv);
  v0 = light1(1.0, 10.0, d0);
  v0 *= smoothstep(r0 * 1.05, r0, len);
  cl = cos(ang + time * 2.0) * 0.5 + 0.5;

  // high light - 简化计算
  float a = time * -1.0;
  float2 pos = float2(cos(a), sin(a)) * r0;
  d = distance(uv, pos);
  v1 = light2(1.5, 5.0, d);
  v1 *= light1(1.0, 50.0, d0);

  // back decay
  v2 = smoothstep(1.0, mix(innerRadius, 1.0, n0 * 0.5), len);

  // hole
  v3 = smoothstep(innerRadius, mix(innerRadius, 1.0, 0.5), len);

  // color - 简化混合计算
  float3 col = mix(color1, color2, cl);
  col = mix(color3, col, v0);
  col = (col + v1) * v2 * v3;
  col.rgb = clamp(col.rgb, 0.0, 1.0);

  fragColor = extractAlpha(col);
}

// Fragment shader
fragment float4 noiseHaloFragmentShader(VertexOut in [[stage_in]],
                                        constant NoiseHaloParams &params
                                        [[buffer(0)]]) {
  // 将纹理坐标转换为屏幕坐标 (centered, aspect-corrected)
  float2 fragCoord = in.texCoord * params.resolution;
  float2 uv = (fragCoord * 2.0 - params.resolution.xy) / params.resolution.y;

  float4 col;
  draw(col, uv, params.time);

  // Background color
  float3 bg = float3(sin(params.time) * 0.5 + 0.5) * 0.0 + float3(0.0);

  // Normal blend
  float4 fragColor;
  fragColor.rgb = mix(bg, col.rgb, col.a);
  fragColor.a = 1.0;

  return fragColor;
}
