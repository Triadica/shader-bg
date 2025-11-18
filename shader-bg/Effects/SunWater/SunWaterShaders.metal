
// Forked from https://www.shadertoy.com/view/MstGz4

#include <metal_stdlib>
using namespace metal;

struct SunWaterData {
  float time;
  float2 resolution;
  float2 mouse;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex VertexOut sunWater_vertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0, 1);
  out.uv = (positions[vertexID] + 1.0) * 0.5;
  return out;
}

// 绘制光晕
float3 sunWater_drawHolo(float2 pos, float2 uv, float range, float power,
                         float aspect) {
  uv.x *= aspect;
  float dis = distance(uv, pos);
  float3 result = float3(0.0);
  if (dis < range) {
    result =
        mix(float3(0.36, 0.174, 0.119), float3(0.0), pow(dis / range, power));
  }
  return result;
}

// 绘制太阳
float3 sunWater_drawSun(float2 pos, float2 uv, float range, float sunrange,
                        float power, float aspect) {
  uv.x *= aspect;
  float dis = distance(uv, pos);
  float3 result = float3(0.0);
  if (dis < range) {
    result = float3(1.0, 0.974, 0.647);
  } else if (dis >= range && dis < range + sunrange) {
    result = mix(float3(1.0, 0.974, 0.007), float3(0.0),
                 pow((dis - range) / sunrange, power));
  }
  return result;
}

// 绘制波浪
float3 sunWater_drawWave(float speed, float range, float height, float offset,
                         float power, float2 uv, float dis, float iTime) {
  float3 finb =
      mix(float3(0.796, 0.796, 0.745), float3(0.513, 0.513, 0.486), dis);
  float siny =
      offset + height * pow(sin(uv.x * range + iTime * speed) + 1.0, power);
  if (uv.y > siny) {
    finb = float3(1.0);
  }
  return finb;
}

fragment float4 sunWater_fragment(VertexOut in [[stage_in]],
                                  constant SunWaterData &params [[buffer(0)]]) {
  float aspect = params.resolution.x / params.resolution.y;
  float2 uv = in.uv;
  float dis = distance(uv, float2(0.5));

  // 渐变背景
  float4 fin =
      mix(float4(0.91, 0.91, 0.87, 1.0), float4(0.65, 0.65, 0.517, 1.0), dis);

  // 添加光晕
  fin.rgb += sunWater_drawHolo(float2(0.5, 0.7), uv, 0.7, 0.7, aspect);

  // 添加多层波浪（从上到下）
  fin.rgb *=
      sunWater_drawWave(1.4, 70.0, 0.017, 0.5, 1.3, uv, dis, params.time);
  fin.rgb *=
      sunWater_drawWave(1.8, 60.0, 0.015, 0.487, 1.3, uv, dis, params.time);
  fin.rgb *=
      sunWater_drawWave(2.2, 50.0, 0.013, 0.462, 1.3, uv, dis, params.time);
  fin.rgb *=
      sunWater_drawWave(2.5, 35.0, 0.011, 0.45, 1.3, uv, dis, params.time);

  // 添加太阳
  fin.rgb += sunWater_drawSun(float2(0.5, 0.7), uv, 0.03, 0.03, 0.02, aspect);

  return fin;
}
