#include <metal_stdlib>
using namespace metal;

struct Sunflower3Data {
  float time;
  float2 resolution;
  float2 padding;
};

#define N 10.0

static float4 sunflower3_effect(float2 u, float time, float2 resolution) {
  u = (u + u - resolution) / resolution.y;

  // 降低动画速度到 1/15 (0.33 * 0.2 = 0.066)
  float t = time * 0.066;
  float r = length(u);
  float a = atan2(u.y, u.x);
  float i = floor(r * N);

  a *= floor(pow(128.0, i / N));
  a += 20.0 * sin(0.5 * t) + 123.34 * i - 100.0 * r * cos(0.5 * t);

  r += (0.5 + 0.5 * cos(a)) / N;
  r = floor(N * r) / N;

  float4 o = (1.0 - r) * float4(0.5, 1.0, 1.5, 1.0);

  return o;
}

kernel void sunflower3Compute(texture2d<float, access::write> output
                              [[texture(0)]],
                              constant Sunflower3Data &data [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = sunflower3_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
