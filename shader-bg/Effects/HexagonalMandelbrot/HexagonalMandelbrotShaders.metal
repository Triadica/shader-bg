// Forked from https://www.shadertoy.com/view/4sjSRt

#include <metal_stdlib>
using namespace metal;

struct HexagonalMandelbrotData {
  float time;
  float2 resolution;
  float2 padding;
};

#define PI 3.141592654
#define TAU (2.0 * PI)

// GLSL mod() 函数 - 与 Metal fmod() 不同！
static float2 glsl_mod(float2 x, float2 y) { return x - y * floor(x / y); }

// License: Unknown, author: Martijn Steinrucken, found:
// https://www.youtube.com/watch?v=VmrIDyYiJBA
static float2 hexmand_hextile(thread float2 &p) {
  // See Art of Code: Hexagonal Tiling Explained!
  const float2 sz = float2(1.0, sqrt(3.0));
  const float2 hsz = 0.5 * sz;

  float2 p1 = glsl_mod(p, sz) - hsz;
  float2 p2 = glsl_mod(p - hsz, sz) - hsz;
  float2 p3 = dot(p1, p1) < dot(p2, p2) ? p1 : p2;
  float2 n = ((p3 - p + hsz) / sz);
  p = p3;

  n -= float2(0.5);
  // Rounding to make hextile 0,0 well behaved
  return round(n * 2.0) * 0.5;
}

// License: Unknown, author: Matt Taylor (https://github.com/64), found:
// https://64.github.io/tonemapping/
static float3 hexmand_aces_approx(float3 v) {
  v = max(v, 0.0);
  v *= 0.6;
  float a = 2.51;
  float b = 0.03;
  float c = 2.43;
  float d = 0.59;
  float e = 0.14;
  return clamp((v * (a * v + b)) / (v * (c * v + d) + e), 0.0, 1.0);
}

// License: MIT, author: Inigo Quilez, found:
// https://www.iquilezles.org/www/articles/smin/smin.htm
static float hexmand_pmin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

static float hexmand_pmax(float a, float b, float k) {
  return -hexmand_pmin(-a, -b, k);
}

static float2x2 hexmand_rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return float2x2(c, s, -s, c);
}

static float3 hexmand_palette(float a) {
  return (1.0 + sin(float3(0.0, 1.0, 2.0) + a));
}

static float3 hexmand_effect(float2 p, float time, float2 resolution) {
  float tm = -time * 0.25;
  const float MaxIter = 22.0;
  const float zz = 1.0;
  const float b = 0.1;

  float2 op = p;
  p = p.yx;

  float2 center = float2(-0.4, 0.0);
  float2 c =
      center + p * 0.5 * (3.0 / 2.0); // 图案缩小到 2/3（坐标范围放大到 3/2）
  float2 z = c;

  float2 z2;

  float s = 1.0;
  float i = 0.0;
  for (; i < MaxIter; ++i) {
    z2 = z * z;
    float ss = sqrt(z2.x + z2.y);
    if (ss > 2.0)
      break;
    s *= 2.0;
    s *= ss;
    z = float2(z2.x - z2.y, 2.0 * z.x * z.y) + c;
  }

  float2 p2 = z / zz;
  float a = 0.1 * tm;
  p2 = hexmand_rot(a) * p2;
  p2 += sin(float2(1.0, sqrt(0.5)) * a * b) / b;

  const float gfo = 0.5;
  float fo = (gfo * 1e-3) + s * (gfo * 3e-3);
  float2 c2 = p2;
  hexmand_hextile(c2);

  float gd0 = length(c2) - 0.25;
  float gd1 = abs(c2.y);
  const float2 n2 = hexmand_rot(60.0 * PI / 180.0) * float2(0.0, 1.0);
  const float2 n3 = hexmand_rot(-60.0 * PI / 180.0) * float2(0.0, 1.0);
  float gd2 = abs(dot(n2, c2));
  float gd3 = abs(dot(n3, c2));
  gd1 = min(gd1, gd2);
  gd1 = min(gd1, gd3);
  float gd = gd0;
  gd = hexmand_pmax(gd, -(gd1 - 0.025), 0.075);
  gd = min(gd, gd1);
  gd = hexmand_pmin(gd, gd0 + 0.2, 0.025);
  gd = abs(gd);
  gd -= fo;

  float3 col = float3(0.0);

  if (i < MaxIter) {
    // 逃逸了，提前跳出循环 - 不渲染
  } else {
    // 完成所有迭代，未逃逸 - 渲染六边形图案
    float gf = (gfo * 1e-2) / max(gd, fo);
    // gf *= sqrt(gf);  // 原代码中被注释掉
    col += gf * hexmand_palette(tm + (p2.x - p2.y) + op.x);
  }

  float div = 6.0 * max(round(resolution.y / 1080.0), 1.0);

  // 弱化扫描线效果：从 0.5-1.0 改为 0.85-1.0
  col *= sqrt(0.5) * (0.85 + 0.15 * sin(op.y * resolution.y * TAU / div));
  col = hexmand_aces_approx(col);
  col = sqrt(col);

  // 降低整体亮度，避免过亮的白色
  col *= 0.85;

  return col;
}

kernel void hexagonalMandelbrotCompute(texture2d<float, access::write> output
                                       [[texture(0)]],
                                       constant HexagonalMandelbrotData &data
                                       [[buffer(0)]],
                                       uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float2 q = fragCoord / resolution;
  float2 p = -1.0 + 2.0 * q;
  p.x *= resolution.x / resolution.y;

  float3 col = hexmand_effect(p, data.time, resolution);

  output.write(float4(col, 1.0), gid);
}
