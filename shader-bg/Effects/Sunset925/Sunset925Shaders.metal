// Sunset 9:25 effect
// Sunset scene with waves and rays
// Forked from https://www.shadertoy.com/view/MdsSzf

#include <metal_stdlib>
using namespace metal;

struct Sunset925Data {
  float time;
  float2 resolution;
  float2 padding;
};

static float3 sunset_toGLColor(float3 color) { return color * 0.00392156862; }

static float4 sunset_925_effect(float2 fragCoord, float time,
                                float2 resolution) {
  // 减慢动画速度到 1/8 (原来 1/2 的 1/4)
  float t = time * 0.125;

  float2 uv = fragCoord.xy / resolution.x;
  float smoothness = 0.002;

  float2 p = float2(0.5, 0.5 * resolution.y / resolution.x);

  float3 col1 = sunset_toGLColor(float3(203, 136, 180));
  float3 col2 = sunset_toGLColor(float3(149, 165, 166));
  float3 col3 = sunset_toGLColor(float3(52, 152, 219));
  float3 col4 = sunset_toGLColor(float3(22, 160, 133));
  float3 col5 = sunset_toGLColor(float3(14, 122, 160));
  float3 col6 = sunset_toGLColor(float3(14, 12, 60));
  float3 col7 = sunset_toGLColor(float3(241, 200, 165));
  float3 col8 = float3(1., 1., 1.);
  float3 col9 = float3(1., 1., 1.);

  float3 col = col2;

  // shadow shape
  float2 q = p - uv;
  q *= float2(0.5, 2.5);  // scale
  q += float2(0.0, -0.6); // translate
  float shape = 1. - smoothstep(0., 0.15, length(q));
  col = col + col9 * 0.3 * shape;

  // object shape
  q = p - uv;
  float qLen = length(q);
  float sfunc = 0.2 + 0.01 * exp(sin(atan2(q.y, q.x) * 4.) * 0.9);
  shape = 1. - smoothstep(sfunc, sfunc + smoothness, qLen);
  col = mix(col, col1, shape);

  float gradShape = 1. - smoothstep(sfunc - 0.05, sfunc, qLen);
  float rayShape = shape;
  float waveShape1 = shape;
  float waveShape2 = shape;

  // rays and sun
  sfunc = 0.05 + 0.01 * exp(sin(atan2(q.y, q.x) * 10.) * 0.5);
  rayShape *= 1. - smoothstep(sfunc, sfunc + 0.2, qLen);
  float spec = 40. + 3. * sin(t) + sin(t * 0.8);
  col7 += pow(1. - qLen, spec);
  col = mix(col, col7, rayShape);

  // wave 1
  float waveFunc = 0.3 + (0.01 * sin(uv.x * 35. + t * 2.)) +
                   (0.005 * sin(uv.x * 20. + t * 0.5));
  waveShape1 *= 1. - smoothstep(waveFunc, waveFunc + smoothness, uv.y);
  col = mix(col, col3, waveShape1);

  // wave 2
  waveFunc = 0.3 + (0.02 * sin(uv.x * 20. + t * 2.)) +
             (0.005 * sin(uv.x * 30. + t * 0.7));
  waveShape2 *= 1. - smoothstep(waveFunc, waveFunc + smoothness, uv.y);
  float waveTop = 1. - smoothstep(waveFunc - 0.005, waveFunc, uv.y);
  col5 = mix(col6, col5, 0.5 + uv.y * 1.7);
  col4 = mix(col3, col5, waveTop);
  col = mix(col, col4, waveShape2);

  // inner shadow
  col8 *= gradShape;
  col = col + col8 * 0.05;

  // highlight
  q += float2(-0.2, 0.15);
  shape = 1. - smoothstep(0., 0.2, length(q));
  col = col + col8 * 0.6 * shape;

  return float4(col, 1.0);
}

kernel void sunset925Compute(texture2d<float, access::write> output
                             [[texture(0)]],
                             constant Sunset925Data &data [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  // 翻转 Y 坐标以匹配 GLSL 的坐标系
  float2 fragCoord = float2(gid.x, resolution.y - gid.y);

  float4 col = sunset_925_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
