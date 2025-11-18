// Forked from https://www.shadertoy.com/view/lctBR8

#include <metal_stdlib>
using namespace metal;

struct InfiniteRingData {
  float time;
  float2 resolution;
  float2 padding;
};

#define MAXSTEPS 128
#define MAXDIST 100.0
#define PI 3.1415926535898
#define TWOPI 6.28318530718
#define EPSILON 0.01
#define RINGS 6.0
#define GLOW_INTENSITY 1.2
#define SPIRAL_SPEED 3.0

// 旋转矩阵
static float2x2 ring_rotate2D(float angle) {
  return float2x2(cos(angle), -sin(angle), sin(angle), cos(angle));
}

// 彩色渐变
static float3 ring_colorGradient(float t) {
  return float3(0.5) + float3(0.5) * sin(TWOPI * t + float3(1.0, 2.5, 6.0));
}

// 螺旋位移
static float3 ring_spiralDisplacement(float3 p, float phase) {
  float angle = phase * TWOPI * SPIRAL_SPEED + p.z * 0.9;
  p.xy += float2(cos(angle), sin(angle)) * 0.5;
  return p;
}

// 圆环距离函数
static float ring_sdRing(float3 p, float innerRadius, float thickness,
                         float phase) {
  p.xy = ring_rotate2D(phase * TWOPI) * p.xy; // 动态旋转
  float r = length(p.xy) - innerRadius;
  return abs(r) - thickness;
}

// 距离场定义
static float ring_map(float3 p, float time, float phase) {
  p = ring_spiralDisplacement(p, phase); // 应用螺旋位移
  float d = 1e6;
  for (float i = 0.0; i < RINGS; i++) {
    float radius = 1.2 + 0.6 * i;                  // 每个圆环半径增加
    float thickness = 0.04 + 0.02 * sin(time + i); // 动态厚度
    d = min(d, ring_sdRing(p, radius, thickness, phase));
  }
  return d;
}

// 距离场交互
static float3 ring_intersect(float3 ro, float3 rd, float time, float phase) {
  float3 glow = float3(0.0);
  float d = 0.0;
  for (int i = 0; i < MAXSTEPS; i++) {
    float3 p = ro + rd * d;
    float res = ring_map(p, time, phase);
    if (res < EPSILON || d > MAXDIST) {
      glow += ring_colorGradient(length(p.xy) * 0.2) * exp(-0.15 * d) *
              GLOW_INTENSITY;
      break;
    }
    d += res;
  }
  return glow;
}

static float4 infinite_ring_effect(float2 fragCoord, float time,
                                   float2 resolution) {
  // 降低速度到 1/20
  float slowTime = time * 0.05;

  // 动态控制参数
  float phase = fmod(slowTime * 0.15, 1.0);

  // 归一化像素坐标
  float2 uv = (fragCoord - 0.5 * resolution) / resolution.y;

  // 相机设置
  float3 ro = float3(0.0, 0.0, -8.0);     // 摄像机位置
  float3 rd = normalize(float3(uv, 1.0)); // 光线方向

  // 计算交点
  float3 glow = ring_intersect(ro, rd, slowTime, phase);

  // 渲染最终颜色
  return float4(glow, 1.0);
}

kernel void infiniteRingCompute(texture2d<float, access::write> output
                                [[texture(0)]],
                                constant InfiniteRingData &data [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = infinite_ring_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
