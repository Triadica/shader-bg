// Forked from https://www.shadertoy.com/view/clKXDc

#include <metal_stdlib>
using namespace metal;

struct ElectricityData {
  float time;
  float2 resolution;
  float2 padding;
};

// Hash functions
static float elec_hash_float(float p) {
  p = fract(p * 0.011);
  p *= p + 7.5;
  p *= p + p;
  return fract(p);
}

static float elec_hash_vec2(float2 p) {
  float3 p3 = fract(float3(p.x, p.y, p.x) * 0.13);
  p3 += dot(p3, p3.yzx + 3.333);
  return fract((p3.x + p3.y) * p3.z);
}

static float elec_noise(float3 x) {
  const float3 step = float3(110.0, 241.0, 171.0);

  float3 i = floor(x);
  float3 f = fract(x);

  // For performance, compute the base input to a 1D hash from the integer part
  // of the argument and the incremental change to the 1D based on the 3D -> 1D
  // wrapping
  float n = dot(i, step);

  float3 u = f * f * (3.0 - 2.0 * f);
  return mix(
      mix(mix(elec_hash_float(n + dot(step, float3(0.0, 0.0, 0.0))),
              elec_hash_float(n + dot(step, float3(1.0, 0.0, 0.0))), u.x),
          mix(elec_hash_float(n + dot(step, float3(0.0, 1.0, 0.0))),
              elec_hash_float(n + dot(step, float3(1.0, 1.0, 0.0))), u.x),
          u.y),
      mix(mix(elec_hash_float(n + dot(step, float3(0.0, 0.0, 1.0))),
              elec_hash_float(n + dot(step, float3(1.0, 0.0, 1.0))), u.x),
          mix(elec_hash_float(n + dot(step, float3(0.0, 1.0, 1.0))),
              elec_hash_float(n + dot(step, float3(1.0, 1.0, 1.0))), u.x),
          u.y),
      u.z);
}

static float3 elec_effect(float2 uv, float time, float2 resolution) {
  float3 col = float3(0.0);
  float pinch = uv.x * (1.0 - uv.x);

  // 动画速度降低到 1/10
  float slowTime = time * 0.1;

  float masterheight = (uv.y - 0.5) * 15.0 - sin(slowTime * 2.0 + uv.x * 10.0) -
                       sin(slowTime * 10.0 + uv.x * 25.0) * 0.8 -
                       sin(slowTime * 2.0 + uv.x * 45.0) * 0.6;
  masterheight *= pow(abs(pinch), 0.1) * -0.02;

  for (int i = 0; i < 3; i++) {
    float noiseofs =
        elec_noise(float3(uv.x * 35.0, slowTime * 15.0, float(i) * 10.0)) *
            2.0 -
        1.0;

    float offset = 0.5;
    offset += noiseofs * 0.1 * pinch;

    float invHeight = 15.0;
    invHeight /= pow(pinch, 3.0);

    float func = (uv.y - offset + masterheight) * invHeight -
                 sin(slowTime * 6.0 + uv.x * 20.0 + float(i) * 4.0);
    func *= 3.0;

    float blue = 3.0 / pow(abs(func), 0.4);

    col.b += blue * 0.4;
    col.g += blue * 0.2;
  }

  return col;
}

kernel void electricityCompute(texture2d<float, access::write> output
                               [[texture(0)]],
                               constant ElectricityData &data [[buffer(0)]],
                               uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float2 uv = fragCoord / resolution;

  float3 col = elec_effect(uv, data.time, resolution);

  output.write(float4(col, 1.0), gid);
}
