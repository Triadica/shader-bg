//
//  NewtonCloudShaders.metal
//  shader-bg
//
//  Newton Cloud effect
//  Ported to Metal for macOS
//  Forked from https://www.shadertoy.com/view/w3jXWR

#include <metal_stdlib>
using namespace metal;

// 常量定义
#define POWER 0.0
#define PI 3.14159265
#define MAX_ITERATIONS 30

struct NewtonCloudParams {
  float time;
  float2 resolution;
  int padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 复数运算辅助函数
float2 cx_mul(float2 a, float2 b) {
  return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

float2 cx_div(float2 a, float2 b) {
  float denom = b.x * b.x + b.y * b.y;
  return float2((a.x * b.x + a.y * b.y) / denom,
                (a.y * b.x - a.x * b.y) / denom);
}

float cx_abs(float2 a) { return sqrt(a.x * a.x + a.y * a.y); }

float2 cx_sub(float2 a, float2 b) { return float2(a.x - b.x, a.y - b.y); }

float2 cx_sin(float2 a) {
  return float2(sin(a.x) * cosh(a.y), cos(a.x) * sinh(a.y));
}

float2 cx_cos(float2 a) {
  return float2(cos(a.x) * cosh(a.y), -sin(a.x) * sinh(a.y));
}

// 复数函数 f(z) = sin(z) + POWER
float2 f(float2 z, float power) {
  float2 sinz = cx_sin(z);
  return float2(sinz.x + power, sinz.y);
}

// 导数 f'(z) = cos(z)
float2 fPrim(float2 z) { return cx_cos(z); }

// 圆反演
float2 circleInvert(float2 pos, float3 circle) {
  float2 diff = pos - circle.xy;
  float lenSq = dot(diff, diff);
  return (diff * circle.z * circle.z) / lenSq + circle.xy;
}

// 牛顿迭代法
float newtonRapson(float2 z, float time) {
  // 使用时间变量创建动画圆
  float angle = time * 0.3;
  float2 circleCenter = float2(cos(angle) * 0.5, sin(angle * 1.3) * 0.5);
  float3 circle = float3(circleCenter, 1.2);

  z = circleInvert(z, circle);

  float2 oldZ = z;
  float s = 0.0;
  float2 one = float2(1.0, 0.0);

  for (int i = 0; i < MAX_ITERATIONS; i++) {
    // 使用随时间变化的 POWER 值
    float power = POWER + sin(time * 0.5) * 0.5;
    z = cx_sub(z, cx_div(f(z, power), fPrim(z)));

    if (abs(oldZ.x - z.x) < 0.000000001 && abs(oldZ.y - z.y) < 0.000000001) {
      break;
    }

    float2 w = cx_div(one, cx_sub(oldZ, z));
    s += exp(-cx_abs(w));
    oldZ = z;
  }

  return s;
}

vertex VertexOut newtonCloudVertex(uint vertexID [[vertex_id]]) {
  // 全屏三角形
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

fragment float4 newtonCloudFragment(VertexOut in [[stage_in]],
                                    constant NewtonCloudParams &params
                                    [[buffer(0)]]) {
  // Fragment coordinates
  float2 fragCoord = in.uv * params.resolution;

  // 归一化坐标，中心为 (0, 0)
  float2 uv = (fragCoord - params.resolution.xy / 2.0) / params.resolution.y;

  // 执行牛顿迭代
  float result = newtonRapson(uv * 3.0, params.time);

  // 计算颜色 - 背景黑色，图案浅蓝色/白色
  float c = result * 0.1;

  // 浅蓝色到白色的渐变 (R: 0.7, G: 0.85, B: 1.0)
  float3 color = float3(0.7, 0.85, 1.0) * c;

  return float4(color, 1.0);
}
