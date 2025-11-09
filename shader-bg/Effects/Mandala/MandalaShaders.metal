// Mandala 2D - 曼陀罗图案效果
// Based on: Xavier Benech's Mandala 2D shader
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
// License.
// Forked from https://www.shadertoy.com/view/MtcSz4

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265

// 圆形函数
float circle(float2 p, float r, float width) {
  float d = 0.0;
  d += smoothstep(1.0, 0.0, width * abs(p.x - r));
  return d;
}

// 弧形函数
float arc(float2 p, float r, float a, float width) {
  float d = 0.0;
  if (abs(p.y) < a) {
    d += smoothstep(1.0, 0.0, width * abs(p.x - r));
  }
  return d;
}

// 玫瑰线函数
float rose(float2 p, float t, float width) {
  const float a0 = 6.0;
  float d = 0.0;
  p.x *= 7.0 + 8.0 * t;
  d += smoothstep(1.0, 0.0, width * abs(p.x - sin(a0 * p.y)));
  d += smoothstep(1.0, 0.0, width * abs(p.x - abs(sin(a0 * p.y))));
  d += smoothstep(1.0, 0.0, width * abs(abs(p.x) - sin(a0 * p.y)));
  d += smoothstep(1.0, 0.0, width * abs(abs(p.x) - abs(sin(a0 * p.y))));
  return d;
}

// 玫瑰线函数2（使用cos）
float rose2(float2 p, float t, float width) {
  const float a0 = 6.0;
  float d = 0.0;
  p.x *= 7.0 + 8.0 * t;
  d += smoothstep(1.0, 0.0, width * abs(p.x - cos(a0 * p.y)));
  d += smoothstep(1.0, 0.0, width * abs(p.x - abs(cos(a0 * p.y))));
  d += smoothstep(1.0, 0.0, width * abs(abs(p.x) - cos(a0 * p.y)));
  d += smoothstep(1.0, 0.0, width * abs(abs(p.x) - abs(cos(a0 * p.y))));
  return d;
}

// 螺旋线函数
float spiral(float2 p, float width) {
  float d = 0.0;
  d += smoothstep(1.0, 0.0, width * abs(p.x - 0.5 * p.y / PI));
  d += smoothstep(1.0, 0.0, width * abs(p.x - 0.5 * abs(p.y) / PI));
  d += smoothstep(1.0, 0.0, width * abs(abs(p.x) - 0.5 * p.y / PI));
  d += smoothstep(1.0, 0.0, width * abs(abs(p.x) - 0.5 * abs(p.y) / PI));
  return d;
}

kernel void mandalaCompute(texture2d<float, access::write> output
                           [[texture(0)]],
                           constant float &time [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = float2(output.get_width(), output.get_height());
  float2 fragCoord = float2(gid);

  float2 uv = fragCoord / resolution;
  float2 p = uv - 0.5;
  p.x *= resolution.x / resolution.y;

  // 缩小图案到 1/2 大小（放大坐标系到2倍）
  p *= 2.0;

  // 转换为极坐标
  float2 f = float2(sqrt(p.x * p.x + p.y * p.y), atan2(p.y, p.x));

  // 减慢时间到 1/16
  float t = time * 0.0625;

  float T0 = cos(0.3 * t);
  float T1 = 0.5 + 0.5 * cos(0.3 * t);
  float T2 = sin(0.15 * t);

  float m0 = 0.0;
  float m1 = 0.0;
  float m2 = 0.0;
  float m3 = 0.0;
  float m4 = 0.0;

  if (f.x < 0.7325) {
    f.y += 0.1 * t;
    float2 c;
    float2 f2;

    c = float2(0.225 - 0.1 * T0, PI / 4.0);
    if (f.x < 0.25) {
      for (float i = 0.0; i < 2.0; i += 1.0) {
        f2 = f - c * floor(f / c) - 0.5 * c;
        m0 += spiral(float2(f2.x, f2.y), 192.0);
      }
    }

    c = float2(0.225 + 0.1 * T0, PI / 4.0);
    if (f.x > 0.43) {
      for (float i = 0.0; i < 2.0; i += 1.0) {
        f.y += PI / 8.0;
        f2 = f - c * floor(f / c) - 0.5 * c;
        m1 += rose((0.75 - 0.5 * T0) * f2, 0.4 * T1, 24.0);
        m1 += rose2((0.5 + 0.5 * T1) * f2, 0.2 + 0.2 * T0, 36.0);
      }
    }

    c = float2(0.6 - 0.2 * T0, PI / 4.0);
    if (f.x > 0.265) {
      for (float i = 0.0; i < 2.0; i += 1.0) {
        f.y += PI / 8.0;
        f2 = f - c * floor(f / c) - 0.5 * c;
        m2 += spiral(float2((0.25 + 0.5 * T1) * f2.x, f2.y), 392.0);
        m2 += rose2((1.0 + 0.25 * T0) * f2, 0.5, 24.0);
      }
    }

    c = float2(0.4 + 0.23 * T0, PI / 4.0);
    if (f.x < 0.265) {
      for (float i = 0.0; i < 2.0; i += 1.0) {
        f.y += PI / 8.0;
        f2 = f - c * floor(f / c) - 0.5 * c;
        m3 += spiral(float2(f2.x, f2.y), 256.0);
        m3 += rose(f2, 1.5 * T1, 16.0);
      }
    }

    m4 += circle(f, 0.040, 192.0);
    m4 += circle(f, 0.265, 192.0);
    m4 += circle(f, 0.430, 192.0);
  }
  m4 += circle(f, 0.7325, 192.0);

  // 着色
  float z = m0 + m1 + m2 + m3 + m4;
  z *= z;
  z = clamp(z, 0.0, 1.0);
  float3 col = float3(z) * float3(0.33 * T2);

  // 背景
  float3 bkg = float3(0.32, 0.36, 0.4) + p.y * 0.1;
  col += bkg;

  // 暗角效果
  float2 r = -1.0 + 2.0 * uv;
  float vb = max(abs(r.x), abs(r.y));
  col *= (0.15 + 0.85 * (1.0 - exp(-(1.0 - vb) * 30.0)));

  float4 color = float4(col, 1.0);
  output.write(color, gid);
}
