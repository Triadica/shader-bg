#include <metal_stdlib>
using namespace metal;

struct TaijiData {
  float time;
  float2 resolution;
  float2 padding;
};

#define PI 3.141592653

static float taiji_sphere(float2 coord, float2 p, float r) {
  float d = length(coord - p) - r;
  d = 1.0 - d;
  d = smoothstep(0.98, 1.0, d);
  return d;
}

static float2x2 taiji_toRotate(float angle) {
  float2x2 rotate = float2x2(cos(angle), -sin(angle), sin(angle), cos(angle));
  return rotate;
}

static float taiji_random(float2 st) {
  return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

static float4 taiji_effect(float2 fragCoord, float time, float2 resolution) {
  // 降低旋转速度到 1/5
  float slowTime = time * 0.2;

  float2 coord = (fragCoord * 2.0 - resolution) / resolution.y;

  float2 xy = sin(coord * PI * 10.0);
  xy = 1e-2 / abs(xy);

  float c = max(xy.x, xy.y);

  xy = 1e-3 / abs(coord);

  c = max(max(xy.x, xy.y), c);

  c = 0.0;

  float l = length(coord);

  float sr = 0.16;
  float sc = 0.5 + taiji_random(float2(l, l)) * l;
  float se = 0.225;

  float2 scoord = taiji_toRotate(l * PI * 6.0 - slowTime) * coord;
  scoord.y *= sc;

  float s = taiji_sphere(scoord, float2(sr), se) * (0.3 / l);
  c += s;

  scoord = taiji_toRotate(l * PI * 6.0 - slowTime - PI) * coord;
  scoord.y *= sc;

  s = taiji_sphere(scoord, float2(sr), se) * (0.3 / l);
  c -= s;

  float3 col = float3(c) + float3(0.4, 0.6, 0.8) * taiji_random(coord);

  return float4(col, 1.0);
}

kernel void taijiCompute(texture2d<float, access::write> output [[texture(0)]],
                         constant TaijiData &data [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = taiji_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
