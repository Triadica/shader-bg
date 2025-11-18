
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

  const float time2 = iTime * 2.0;
  const float4 colorPhaseOffset = float4(0.0, 1.0, 1.0, 0.0);
  const float cContributionThreshold = 5e-4;
  const float intensityThreshold = 1e-4;

  float i = -7.0;

  // 循环上限 15 次，根据当前权重阈值自动提前退出以节省 GPU 开销
  for (int loop = 0; loop < 15; loop++) {
    i += 1.0;

    float i2 = i * i;
    float c = exp(-0.1 * i2);
    float heightDecay = exp(-0.01 * i2);

    // #define S sin(iTime
    // S*2.+i*2. 表示 sin(iTime*2.+i*2.)
    float phase2 = time2 + i * 2.0;
    float S_amp = sin(phase2);

    // S*2. + U.x / (.2-.1*c) + i*4. 表示 sin(iTime*2. + U.x / (.2-.1*c) + i*4.)
    float denom = 0.2 - 0.1 * c;
    float invDenom = 1.0 / denom;
    float S_wave = sin(time2 + U.x * invDenom + i * 4.0);

    // S+i+vec4(0,1,1,0) 表示为向量分量引入相位偏移
    float4 colorPhase = sin(float4(iTime + i) + colorPhaseOffset);

    // 计算 y 值
    float y =
        (0.08 + 0.02 * S_amp) * heightDecay * S_wave - i / 20.0 + 0.5 - U.y;

    float expArg = -y * k * c;
    expArg = clamp(expArg, -20.0, 5.0);
    float intensity = max(0.0, 1.0 - exp(expArg));

    // 计算颜色贡献
    // 原始 GLSL: O += max(0., 1.-exp(-y*k*c)) * (tanh(40.*y) * (.5 + .4 *
    // S+i+vec4(0,1,1,0)) - O); 这里 - O 在括号内,表示混合操作: O += intensity *
    // (blendedColor - O) 等价于: O = O + intensity * blendedColor - intensity *
    // O = (1-intensity) * O + intensity * blendedColor 即: O = mix(O,
    // blendedColor, intensity)
    float4 baseColor = 0.5 + 0.4 * colorPhase;
    float4 blendedColor = tanh(40.0 * y) * baseColor;
    O += intensity * (blendedColor - O);

    if (c < cContributionThreshold && intensity < intensityThreshold) {
      break;
    }
  }

  // 原始 GLSL 会直接在 0~1 范围内输出颜色，为了恢复原有的高饱和度效果，
  // 这里先做一次安全的 clamp，再对颜色与亮度之间的差异做一次放大。
  float3 color = clamp(O.xyz, 0.0, 1.0);
  float luminance = dot(color, float3(0.299, 0.587, 0.114));
  const float saturationBoost = 1.35;
  float3 luminanceColor = float3(luminance);
  color = clamp(luminanceColor + (color - luminanceColor) * saturationBoost,
                0.0, 1.0);
  color = pow(color, float3(0.9));

  return float4(color, 1.0);
}
