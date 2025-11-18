// Forked https://www.shadertoy.com/view/dtBSRV

#include <metal_stdlib>
using namespace metal;

#define PI 3.141592654
#define TAU (2.0 * PI)
// 减少迭代次数以降低 GPU 开销
constant float MaxIter = 8.0;

struct BubblesUnderwaterParams {
  float time;
  float2 resolution;
  float padding;
};

static float hash(float co) { return fract(sin(co * 12.9898) * 13758.5453); }
static float hash(float2 co) {
  return fract(sin(dot(co, float2(12.9898, 58.233))) * 13758.5453);
}
static float3 hsv2rgb(float3 c) {
  float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
static float2 mod2(thread float2 &p, float2 size) {
  float2 c = floor((p + size * 0.5) / size);
  p = fmod(p + size * 0.5, size) - size * 0.5;
  return c;
}
static float tanh_approx(float x) {
  float x2 = x * x;
  return clamp(x * (27.0 + x2) / (27.0 + 9.0 * x2), -1.0, 1.0);
}
float4 plane(float2 p, float i, float zf, float z, float3 bgcol, float time,
             float2 resolution) {
  float sz = 0.45 * zf; // 稍微增大泡泡以补偿减少的数量
  float2 cp = p;
  float2 cn = mod2(cp, float2(2.0 * sz, sz));
  float h0 = hash(cn + float2(i + 123.4));
  float h1 = fract(4483.0 * h0);
  float h2 = fract(8677.0 * h0);
  float h3 = fract(9677.0 * h0);
  float h4 = fract(7877.0 * h0);
  float h5 = fract(9967.0 * h0);
  // 提前剔除以减少计算
  if (h4 < 0.5) {
    return float4(0.0);
  }
  float fi = exp(-0.25 * max(z - 1.0, 0.0));
  float aa = mix(6.0, 1.0, fi) * 2.0 / resolution.y;
  float r = sz * mix(0.1, 0.35, h0 * h0); // 稍微增大最小半径
  float amp = mix(0.18, 0.4, h3) * r;
  // 简化正弦计算
  cp.x -= amp * sin(mix(3.0, 0.25, h0) * time + TAU * h2);
  cp.x += 0.95 * (sz - r - amp) * sign(h3 - 0.5) * h3;
  cp.y += 0.475 * (sz - 2.0 * r) * sign(h5 - 0.5) * h5;
  float d = length(cp) - r;
  // 简化颜色计算
  float3 hsv = float3(h1, 0.7, 1.4); // 稍微降低饱和度和亮度
  float3 ocol = hsv2rgb(hsv);
  float3 icol = hsv2rgb(hsv * float3(1.0, 0.5, 1.2));
  float3 col = mix(icol, ocol, smoothstep(r, 0.0, -d)) * mix(0.8, 1.0, h0);
  col = mix(bgcol, col, fi);
  float t = smoothstep(aa, -aa, d);
  return float4(col, t);
}
float3 effect(float2 p, float2 pp, float time, float2 resolution) {
  float3 bgcol0 = hsv2rgb(float3(0.66, 0.85, 0.1));
  float3 bgcol1 = hsv2rgb(float3(0.55, 0.66, 0.6));
  float3 bgcol = mix(bgcol1, bgcol0, tanh_approx(1.5 * length(p)));
  float3 col = bgcol;
  for (float i = 0.0; i < MaxIter; ++i) {
    float Near = 4.0;
    float z = MaxIter - i;
    float zf = Near / (Near + MaxIter - i);
    float2 sp = p;
    float h = hash(i + 1234.5);
    // 泡泡向上移动，使用 fmod 实现循环（周期约为 10 秒）
    float movement = mix(0.2, 0.3, h * h) * time * zf;
    sp.y += -fmod(movement, 10.0) + 5.0; // 循环范围：-5 到 +5
    sp += h;
    float4 pcol = plane(sp, i, zf, z, bgcol, time, resolution);
    col = mix(col, pcol.xyz, pcol.w);
  }
  col *= smoothstep(1.4, 0.5, length(pp));
  col = sqrt(col);
  return col;
}
struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex VertexOut bubblesUnderwaterVertex(uint vertexID [[vertex_id]]) {
  const float2 positions[3] = {
      float2(-1.0, -1.0),
      float2(3.0, -1.0),
      float2(-1.0, 3.0),
  };
  const float2 uvs[3] = {
      float2(0.0, 0.0),
      float2(2.0, 0.0),
      float2(0.0, 2.0),
  };

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = uvs[vertexID];
  return out;
}

fragment float4 bubblesUnderwaterShader(VertexOut in [[stage_in]],
                                        constant BubblesUnderwaterParams &params
                                        [[buffer(0)]]) {
  float2 resolution = params.resolution;
  float2 q = in.uv;
  float2 p = -1.0 + 2.0 * q;
  float2 pp = p;
  p.x *= resolution.x / resolution.y;
  float time = params.time; // 时间已经在 CPU 端乘以了 0.1
  float3 col = effect(p, pp, time, resolution);
  return float4(col, 1.0);
}
