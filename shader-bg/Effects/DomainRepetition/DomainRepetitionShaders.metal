// Domain Repetition effect
// Raymarching with domain repetition technique
// Inspired by ShaderToy examples
// Forked from https://www.shadertoy.com/view/4dcBRN

#include <metal_stdlib>
using namespace metal;

struct DomainRepetitionData {
  float time;
  float2 resolution;
  float2 padding;
};

#define RAYMARCH_STEPS 50 // 减少步数以提高性能
#define EPS 0.001

// Random function
static float domain_rand(float2 n) {
  return fract(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
}

// Noise function
static float domain_noise(float2 p) {
  float2 ip = floor(p);
  float2 u = fract(p);
  u = u * u * (3.0 - 2.0 * u);

  float res = mix(mix(domain_rand(ip), domain_rand(ip + float2(1.0, 0.0)), u.x),
                  mix(domain_rand(ip + float2(0.0, 1.0)),
                      domain_rand(ip + float2(1.0, 1.0)), u.x),
                  u.y);
  return res * res;
}

// Domain repetition modifier - returns cell index and modifies p
static float2 domain_pMod2(thread float2 &p, float size) {
  float halfsize = size * 0.5;
  float2 c = floor((p + halfsize) / size);
  p = fmod(p + halfsize, size) - halfsize;
  return c;
}

// Sphere SDF
static float domain_sdSphere(float3 p, float s) { return length(p) - s; }

// Scene map function
static float domain_map(float3 p, float time) {
  float2 pxz = p.xz; // 临时变量避免 Metal 语法错误
  float2 index = domain_pMod2(pxz, 5.0); // 使用原始的 5.0 间距
  p.xz = pxz;                            // 更新 p 的 xz 分量
  float valNoise = domain_noise(index);
  p.y -= valNoise * 14.0; // 使用原始的 14.0 高度系数
  float pulse = (sin(time * length(index)) + 1.0) / 8.0; // 减小脉冲影响
  return domain_sdSphere(p, valNoise * 0.5 + 0.1 + pulse); // 减小球体基础大小
}

// Raymarching
static float domain_raymarch(float3 ro, float3 rd, float time) {
  float t = 0.0;
  for (int i = 0; i < RAYMARCH_STEPS; ++i) {
    float3 p = ro + rd * t;
    float d = domain_map(p, time);

    if (d < EPS) {
      break;
    }

    t += min(d, 2.5);
  }
  return t;
}

// Camera setup
static float3x3 domain_setCamera(float3 ro, float3 ta, float cr) {
  float3 cw = normalize(ta - ro);
  float3 cp = float3(sin(cr), cos(cr), 0.0);
  float3 cu = normalize(cross(cw, cp));
  float3 cv = normalize(cross(cu, cw));
  return float3x3(cu, cv, cw);
}

static float4 domain_repetition_effect(float2 fragCoord, float time,
                                       float2 resolution) {
  // 将旋转速度降低到 1/80 (原来 1/10 的 1/8)
  float slowTime = time * 0.0125;

  float2 uv = fragCoord / resolution.xy;
  uv = uv * 2.0 - 1.0;
  uv.x *= resolution.x / resolution.y;

  // Camera position - slow rotation
  float3 ro =
      float3(12.0 * cos(slowTime / 3.0), 3.0, 12.0 * sin(slowTime / 3.0));
  float3 ta = float3(0.0, 4.0, 0.0);

  float3x3 cam = domain_setCamera(ro, ta, 0.0);
  float3 rd = cam * normalize(float3(uv, 2.0));

  float dist = domain_raymarch(ro, rd, slowTime);

  float fog = 1.0 / (1.0 + dist * dist * 0.001);

  float3 color = fog * float3(1.0, 0.75, 0.0);

  return float4(color, 1.0);
}

kernel void domainRepetitionCompute(texture2d<float, access::write> output
                                    [[texture(0)]],
                                    constant DomainRepetitionData &data
                                    [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = domain_repetition_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
