//
//  HyperbolicRingsShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//  Based on "Hyperbolic Rings" by mla, 2023
//  Fork from https://www.shadertoy.com/view/Dd3cWn

#include <metal_stdlib>
using namespace metal;

#define PI 3.141592654

struct HyperbolicRingsParams {
  float time;
  float2 resolution;
  float2 mouse;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器
vertex VertexOut hyperbolicRingsVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// 复数运算辅助函数
float2 hyperbolicRings_cmul(float2 a, float2 b) {
  return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

float2 hyperbolicRings_cdiv(float2 a, float2 b) {
  float d = dot(b, b);
  return float2(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / d;
}

float2 hyperbolicRings_clog(float2 z) {
  return float2(log(length(z)), atan2(z.y, z.x));
}

// 复数正弦和余弦
float2 hyperbolicRings_csin(float2 z) {
  // sin(a+bi) = sin(a)cosh(b) + i*cos(a)sinh(b)
  return float2(sin(z.x) * cosh(z.y), cos(z.x) * sinh(z.y));
}

float2 hyperbolicRings_ccos(float2 z) {
  // cos(a+bi) = cos(a)cosh(b) - i*sin(a)sinh(b)
  return float2(cos(z.x) * cosh(z.y), -sin(z.x) * sinh(z.y));
}

float2 hyperbolicRings_ctan(float2 z) {
  // tan(z) = sin(z) / cos(z)
  return hyperbolicRings_cdiv(hyperbolicRings_csin(z), hyperbolicRings_ccos(z));
}

float2 hyperbolicRings_rotate(float2 p, float a) {
  float c = cos(a);
  float s = sin(a);
  return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// 反演变换
bool hyperbolicRings_tryinvert(thread float2 &z, float2 C, float R2) {
  float2 diff = z - C;
  float d2 = dot(diff, diff);
  if (d2 < R2) {
    z = C + diff * R2 / d2;
    return true;
  }
  return false;
}

// Hash 函数用于生成伪随机数
float hyperbolicRings_hash(float2 p) {
  float h = dot(p, float2(127.1, 311.7));
  return fract(sin(h) * 43758.5453123);
}

// 生成程序化纹理（模拟原始 shader 的纹理效果）
float3 hyperbolicRings_proceduralTexture(float2 uv) {
  // 多层噪声和图案叠加
  float2 p = uv * 2.0;

  // 基础波纹图案
  float f = sin(p.x * 3.14159) * sin(p.y * 3.14159);
  f += 0.5 * sin(p.x * 6.28318 + p.y * 4.71239);
  f += 0.25 * sin(p.x * 12.56637 - p.y * 7.85398);

  // 添加一些伪随机噪声
  float2 ip = floor(p);
  float2 fp = fract(p);
  fp = fp * fp * (3.0 - 2.0 * fp); // smoothstep

  float n = mix(mix(hyperbolicRings_hash(ip),
                    hyperbolicRings_hash(ip + float2(1, 0)), fp.x),
                mix(hyperbolicRings_hash(ip + float2(0, 1)),
                    hyperbolicRings_hash(ip + float2(1, 1)), fp.x),
                fp.y);

  f = f * 0.7 + n * 0.3;

  // 生成彩色图案（使用余弦调色板）
  float3 col =
      float3(0.5) + 0.5 * cos(6.28318 * (f * 0.5 + float3(0.0, 0.33, 0.67)));

  // 添加一些对比度和饱和度
  col = col * col * (3.0 - 2.0 * col);

  return col;
}

float3 hyperbolicRings_getcolor(float2 fragCoord,
                                constant HyperbolicRingsParams &params) {
  const int P = 6;
  const int Q = 6;
  const int MAXITER = 100;

  // 计算 icos (inverse cosine scaling factor)
  float icosP = cos(PI / float(P));
  float icosQ = cos(PI / float(Q));
  float2 C = float2(icosP, icosQ);
  float R2 = 1.0 / (dot(C, C) - 1.0);
  float R = sqrt(R2);
  C *= R;

  float2 z = (2.0 * fragCoord - params.resolution) / params.resolution.y;

  // 应用变换：z -> tan(log(z))
  // 这个变换将同心圆环映射到单位圆盘
  z = hyperbolicRings_clog(z);
  z = hyperbolicRings_ctan(1.8237 * z - float2(0.5 * params.time, 0));

  bool flip = dot(z, z) > 1.0;
  if (flip) {
    z /= dot(z, z); // 反演
  }

  // 双曲镶嵌的折叠迭代
  int xflips = 0;
  int yflips = 0;
  int zflips = 0;
  for (; zflips < MAXITER; zflips++) {
    xflips += int(z.x < 0.0);
    yflips += int(z.y < 0.0);
    z = abs(z);
    if (!hyperbolicRings_tryinvert(z, C, R2))
      break;
  }

  if (zflips == MAXITER)
    return float3(0);

  float2 z0 = z;

  // 网格线距离
  float ldist = 1e8;
  ldist = min(ldist, abs(length(C - z) - R));
  ldist = min(ldist, abs(z.x));
  ldist = min(ldist, abs(z.y));

  // 可选的对称操作（在原版中由按键控制，这里默认不应用）
  // if (xflips%2 == 1) z.x = -z.x;
  // if (yflips%2 == 1) z.y = -z.y;
  // if (zflips%2 == 1) z = -z;

  float2 uv = z;
  uv = hyperbolicRings_rotate(uv, 0.25 * PI);
  float k = 2.0 / (1.0 + dot(uv, uv)); // Beltrami-Klein 变换
  k *= 0.5;                            // 额外缩放
  uv *= k;

  // 自动移动模式
  float t = 0.5 * params.time;
  uv += 0.5 * float2(cos(t), sin(0.618 * t));

  // 使用程序化纹理（原版使用 iChannel0 纹理）
  float3 col = hyperbolicRings_proceduralTexture(uv).zyx;
  if (!flip)
    col = col.yzx;

  col = pow(col, float3(2.2));
  col *= 1.5;
  col = smoothstep(float3(0), float3(1), col);
  col = mix(float3(0), col, smoothstep(0.0, 0.02, ldist)); // 网格线

  return col;
}

// 片段着色器
fragment float4 hyperbolicRingsFragment(VertexOut in [[stage_in]],
                                        constant HyperbolicRingsParams &params
                                        [[buffer(0)]]) {
  float2 fragCoord = in.uv * params.resolution;
  float3 col = hyperbolicRings_getcolor(fragCoord, params);
  col = pow(col, float3(0.4545)); // Gamma 校正

  return float4(col, 1.0);
}
