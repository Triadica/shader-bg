
// Forked from https://www.shadertoy.com/view/ldjBRw

#include <metal_stdlib>
using namespace metal;

struct MountainWavesData {
  float time;
  float2 resolution;
  float2 mouse;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex VertexOut mountainWaves_vertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0, 1);
  out.uv = (positions[vertexID] + 1.0) * 0.5;
  return out;
}

fragment float4 mountainWaves_fragment(VertexOut in [[stage_in]],
                                       constant MountainWavesData &params
                                       [[buffer(0)]]) {
  float iTime = params.time;
  float2 iResolution = params.resolution;
  float2 fragCoord = in.uv * iResolution;

  // 初始化输出颜色
  // 原始 GLSL: O.xyz = iResolution
  // 直接使用对应的分量，利用后续混合和 clamp 获得相同的亮度基线
  float4 O = float4(iResolution.x, iResolution.y, iResolution.x, 1.0);
  float2 U = fragCoord;

  // k 使用实际的屏幕高度
  float k = iResolution.y;
  U /= k;

  float i = -15.0;

  // 循环 30 次 (i 从 -15 递增到 15)
  for (int loop = 0; loop < 30; loop++) {
    i += 1.0;

    float c = exp(-0.1 * i * i);

    // #define S sin(iTime
    // S*2.+i*2. 表示 sin(iTime*2.+i*2.)
    float S_amp = sin(iTime * 2.0 + i * 2.0);

    // S*2. + U.x / (.2-.1*c) + i*4. 表示 sin(iTime*2. + U.x / (.2-.1*c) + i*4.)
    float S_wave = sin(iTime * 2.0 + U.x / (0.2 - 0.1 * c) + i * 4.0);

    // S+i+vec4(0,1,1,0) 表示为向量分量引入相位偏移
    float4 colorPhase = sin(float4(iTime + i) + float4(0.0, 1.0, 1.0, 0.0));

    // 计算 y 值
    float y = (0.08 + 0.02 * S_amp) * exp(-0.01 * i * i) * S_wave - i / 20.0 +
              0.5 - U.y;

    float intensity = max(0.0, 1.0 - exp(-y * k * c));

    // 计算颜色贡献
    // 原始 GLSL: O += max(0., 1.-exp(-y*k*c)) * (tanh(40.*y) * (.5 + .4 *
    // S+i+vec4(0,1,1,0)) - O); 这里 - O 在括号内,表示混合操作: O += intensity *
    // (blendedColor - O) 等价于: O = O + intensity * blendedColor - intensity *
    // O = (1-intensity) * O + intensity * blendedColor 即: O = mix(O,
    // blendedColor, intensity)
    float4 baseColor = 0.5 + 0.4 * colorPhase;
    float4 blendedColor = tanh(40.0 * y) * baseColor;
    O += intensity * (blendedColor - O);
  }

  // 将结果重新映射到 [0, 1]，保留正负波形信息同时避免黑带
  float4 finalColor = clamp(0.55 + 0.45 * O, 0.0, 1.0);

  return float4(finalColor.rgb, 1.0);
}
