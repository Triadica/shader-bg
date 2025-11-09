#include <metal_stdlib>
using namespace metal;

struct MicrowavesData {
  float time;
  float2 resolution;
  float2 padding;
};

// Palette function
static float3 micro_palette(float t, float3 a, float3 b, float3 c, float3 d) {
  return a + b * cos(6.28318 * (c * t + d));
}

// Sin wave function
static float micro_w(float x, float p, float time) {
  x *= 5.0;
  float t = p * 0.5 + sin(time * 0.25) * 10.5;
  return (sin(x * 0.25 + t) * 5.0 + sin(x * 4.5 + t * 3.0) * 0.2 + 
          sin(x + t * 3.0) * 2.3 + sin(x * 0.8 + t * 1.1) * 2.5) * 0.275;
}

static float4 microwaves_effect(float2 fragCoord, float time, float2 resolution) {
  // 降低速度到 1/20 (1/10 的 1/2)
  float slowTime = time * 0.05;
  
  float2 r = resolution;
  float2 st = (fragCoord + fragCoord - r) / r.y;
  
  float th = 0.05;  // thickness
  
  // smoothing factor
  float2 absst = abs(st);
  float2 s1 = smoothstep(float2(1.0, 0.2), float2(2.0, 0.7), absst);
  float sm = 15.0 / r.y + 0.85 * length(s1);
  
  float c = 0.0;
  float t = slowTime * 0.25;
  float n = floor((st.y + t) / 0.1);
  float y = fract((st.y + t) / 0.1);
  
  float3 clr = float3(0.0);
  
  for (float i = -5.0; i < 5.0; i++) {
    float f = micro_w(st.x, (n - i), slowTime) - y - i;
    c = mix(c, 0.0, smoothstep(-0.3, abs(st.y), f));
    c += smoothstep(th + sm, th - sm, abs(f)) * (1.0 - abs(st.y) * 0.75) +
         smoothstep(5.5 - abs(f * 0.5), 0.0, f) * 0.25;
    
    float3 palette = micro_palette(
      sin((n - i) * 0.15),
      float3(0.5),
      float3(0.5),
      float3(0.270),
      float3(0.0, 0.05, 0.15)
    );
    
    clr = mix(clr, palette * c, smoothstep(-0.3, abs(st.y), f));
  }
  
  return float4(clr, 1.0);
}

kernel void microwavesCompute(
  texture2d<float, access::write> output [[texture(0)]],
  constant MicrowavesData& data [[buffer(0)]],
  uint2 gid [[thread_position_in_grid]]
) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);
  
  float4 col = microwaves_effect(fragCoord, data.time, resolution);
  
  output.write(col, gid);
}
