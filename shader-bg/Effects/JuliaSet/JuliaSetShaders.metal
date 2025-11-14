// Forked from https://www.shadertoy.com/view/tfXcz2

#include <metal_stdlib>
using namespace metal;

struct JuliaSetData {
  float time;
  float2 resolution;
  float2 padding;
};

// Julia set iteration function
static float2 julia_f(float2 z, float2 c) {
  float re = z.x * z.x - z.y * z.y;
  float im = 2.0 * z.x * z.y;
  return float2(re, im) + c;
}

// Blackbody radiation color function
static float3 julia_blackbody(float t) {
  float T = 1400.0 + 1400.0 * t;
  float3 l = float3(7.4, 5.6, 4.4);
  l = pow(l, float3(5.0)) * (exp(1.43876719683e5 / (T * l)) - 1.0);
  return 1.0 - exp(-5e8 / l);
}

static float4 julia_effect(float2 fragCoord, float time, float2 resolution) {
  // 降低旋转速度到 1/50 (1/5 的 1/10)
  float slowTime = time * 0.02;

  const float R = 40.0;
  float2 z = (2.0 * fragCoord - resolution) / resolution.y;
  z *= 1.5;
  float2 c = 0.7885 * float2(-cos(slowTime), sin(0.5 + slowTime));

  const uint maxIter = 100u;
  uint numIter = 0u;
  float2 res = julia_f(float2(z), c);

  while (numIter <= maxIter && dot(res, res) <= R * R) {
    res = julia_f(res, c);
    numIter++;
  }

  float t = float(numIter) - log2(log2(dot(res, res))) + 4.0;
  float3 col = julia_blackbody(t * 4.0 / float(maxIter));

  return float4(col, 1.0);
}

kernel void juliaSetCompute(texture2d<float, access::write> output
                            [[texture(0)]],
                            constant JuliaSetData &data [[buffer(0)]],
                            uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = julia_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
