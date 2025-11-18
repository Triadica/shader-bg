// Droppy Thingies effect
// Based on shader from ShaderToy
// Animated droplet effect with layers
// Forked from https://www.shadertoy.com/view/X3tczB

#include <metal_stdlib>
using namespace metal;

struct DroppyThingiesData {
  float time;
  float2 resolution;
  float2 padding;
};

// Hash functions
static float droppy_hash12(float2 p) {
  float3 p3 = fract(float3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

static float droppy_hash13(float3 p3) {
  p3 = fract(p3 * 0.1031);
  p3 += dot(p3, p3.zyx + 31.32);
  return fract((p3.x + p3.y) * p3.z);
}

static float droppy_hash14(float4 p4) {
  p4 = fract(p4 * float4(0.1031, 0.1030, 0.0973, 0.1099));
  p4 += dot(p4, p4.wzxy + 33.33);
  return fract((p4.x + p4.y) * (p4.z + p4.w));
}

static float2 droppy_hash21(float n) {
  return fract(sin(float2(n, n + 1.0)) * float2(43758.5453123, 22578.1459123));
}

static void droppy_drawLayer(float2 uv, thread float3 &color, float brightness,
                             float layerId, float time) {
  float colId = floor(uv.x * 2.0);
  uv.x -= colId * 0.5 + 0.25;
  // 使用原始的 -= 方向，粒子从上往下移动
  uv.y -=
      time *
          (1.75 + 0.5 * droppy_hash12(float2(colId * 17.4 + 13.1, layerId))) *
          0.25 +
      droppy_hash12(float2(colId, layerId)) * 2.5;
  float rowId = floor(uv.y / 0.75);
  uv.y = uv.y - (rowId + 1.0) * 0.75;
  float2 warpUv = float2(uv.x * 0.8, 0.15 * uv.y + exp(uv.y * 25.0));
  float mask = step(0.5, droppy_hash13(float3(colId, rowId, layerId)));
  float3 dropColor = pow(float3(0.98, 0.93, 0.1),
                         float3(max(0.0, length(warpUv) * 2000.0 - 20.0)));
  dropColor = mix(dropColor, dropColor.bgr,
                  droppy_hash14(float4(colId, rowId, layerId, 13.1)));
  color += dropColor * mask * brightness;
}

static float4 droppy_thingies_effect(float2 fragCoord, float time,
                                     float2 resolution) {
  // 速度再减慢到 1/4，从 0.125 改为 0.03125 (0.125/4)
  float t = time * 0.03125;

  float2 uv = (fragCoord - float2(0.5 * resolution.x, 0.0)) / resolution.y;
  // 不翻转 y 坐标，保持原始方向
  float3 color = float3(0.0);

  // 粒子数量减少到 1/4，从 20 改为 5
  for (float n = 0.0; n < 5.0; n++) {
    float2 p = uv;
    p *= n + 1.0;
    p += droppy_hash21(n);
    droppy_drawLayer(p, color, exp(-n * 0.1), n, t);
  }

  return float4(color, 1.0);
}

kernel void droppyThingiesCompute(texture2d<float, access::write> output
                                  [[texture(0)]],
                                  constant DroppyThingiesData &data
                                  [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = droppy_thingies_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
