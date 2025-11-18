// Forked from https://www.shadertoy.com/view/WXsSD7

#include <metal_stdlib>
using namespace metal;

struct NewtonBasinsData {
  float time;
  float2 resolution;
  float4 mouse;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器 - 全屏三角形
vertex VertexOut newtonBasins_vertex(uint vertexID [[vertex_id]]) {
  VertexOut out;

  // 全屏三角形的位置
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  float2 uvs[3] = {float2(0.0, 0.0), float2(2.0, 0.0), float2(0.0, 2.0)};

  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = uvs[vertexID];

  return out;
}

// 复数乘法: (a.x + a.y*i) * (b.x + b.y*i)
float2 cmul(float2 a, float2 b) {
  return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

// 复数除法: (a.x + a.y*i) / (b.x + b.y*i)
float2 cdiv(float2 a, float2 b) {
  float d = dot(b, b);
  return float2(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / d;
}

// 计算多项式 f(z) 和其导数 f'(z)
// f(z) = z^5 + z^4 + z^3 + z^2 - const
// f'(z) = 5*z^4 + 4*z^3 + 3*z^2 + 2*z
void polynomials(float2 z, float iTime, thread float2 &f, thread float2 &df) {
  float2 z2 = cmul(z, z);
  float2 z3 = cmul(z2, z);
  float2 z4 = cmul(z2, z2);
  float2 z5 = cmul(z4, z);

  f = z5 + z4 + z3 + z2 - float2(sin(iTime), cos(iTime));
  df = 5.0 * z4 + 4.0 * z3 + 3.0 * z2 + 2.0 * z;
}

// 片段着色器 - 牛顿迭代法绘制分形
fragment float4 newtonBasins_fragment(VertexOut in [[stage_in]],
                                      constant NewtonBasinsData &params
                                      [[buffer(0)]]) {
  float2 fragCoord = in.position.xy;
  float2 iResolution = params.resolution;
  float iTime = params.time;

  // 将屏幕坐标转换为复平面坐标
  float2 z = (fragCoord.xy - iResolution.xy / 2.0) /
             (min(iResolution.x, iResolution.y) / 2.0);

  float2 f, df;
  int i;
  int max_iter = 256;

  // 牛顿迭代法
  for (i = 0; i < max_iter; i++) {
    polynomials(z, iTime, f, df);
    if (dot(f, f) < 1e-6)
      break;
    z -= cdiv(f, df);
  }

  // 根据收敛结果着色
  float2 zf = (z + float2(1.0)) / 2.0;
  float it = float(i) / float(max_iter);

  float4 color =
      float4(cos(zf.y) - 0.25, sin(zf.x), sin(length(zf)) * 0.5, 1.0) +
      it * 8.0;

  return color;
}
