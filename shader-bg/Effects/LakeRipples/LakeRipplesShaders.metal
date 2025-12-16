// Lake Ripples - 极简交互式涟漪效果
// 响应鼠标点击产生涟漪

#include <metal_stdlib>
using namespace metal;

struct InputData {
  int hasMouseActivity;
  float2 mousePosition;
  int rippleCount;
  float4 ripples[8]; // (x, y, age, strength)
};

// 颜色
constant float3 BG_COLOR = float3(0.02, 0.06, 0.12);
constant float3 RIPPLE_COLOR = float3(0.15, 0.35, 0.55);

// 涟漪参数
constant float RIPPLE_SPEED = 0.04; // 更慢的扩散
constant float RIPPLE_DECAY = 0.15; // 更慢的衰减

// 简单涟漪 - 单个圆环
float calcRipple(float2 uv, float2 center, float age, float strength) {
  float dist = length(uv - center);
  float radius = age * RIPPLE_SPEED;
  float fade = exp(-age * RIPPLE_DECAY);

  // 圆环
  float ring = 1.0 - smoothstep(0.0, 0.015, abs(dist - radius));

  return ring * fade * strength / (1.0 + dist * 2.0);
}

kernel void lakeRipplesCompute(texture2d<float, access::write> output
                               [[texture(0)]],
                               constant float &time [[buffer(0)]],
                               constant InputData &inputData [[buffer(1)]],
                               uint2 gid [[thread_position_in_grid]]) {
  uint w = output.get_width();
  uint h = output.get_height();

  if (gid.x >= w || gid.y >= h)
    return;

  float2 uv = float2(gid) / float2(w, h);
  uv.y = 1.0 - uv.y;

  float aspect = float(w) / float(h);

  // 静态渐变背景 (无噪声计算)
  float gradient = uv.y * 0.3 + 0.1;
  float3 color = BG_COLOR * (1.0 + gradient);

  // 涟漪
  float ripple = 0.0;
  for (int i = 0; i < inputData.rippleCount && i < 8; i++) {
    float4 r = inputData.ripples[i];
    float2 uvS = float2(uv.x * aspect, uv.y);
    float2 cS = float2(r.x * aspect, r.y);
    ripple += calcRipple(uvS, cS, r.z, r.w);
  }

  color += RIPPLE_COLOR * ripple * 2.5;

  output.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
}
