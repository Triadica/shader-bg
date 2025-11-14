//
//  GlowyOrbShaders.metal
//  shader-bg
//
//  Created on 2025-11-03.
//  Ray-marched glowing orb with animated noise
// Forked from https://www.shadertoy.com/view/mdcSDB

#include <metal_stdlib>
using namespace metal;

// 降低迭代次数以提高性能
#define MAX_RAY_MARCH_STEPS 20
#define MAX_DISTANCE 4.0
#define SURFACE_DISTANCE 0.005

struct GlowyOrbParams {
  float time;
  float2 resolution;
  float padding;
};

struct Hit {
  float dist;
  float closest_dist;
  float3 p;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// Perlin noise functions
static float4 mod289(float4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
static float4 perm(float4 x) { return mod289(((x * 34.0) + 1.0) * x); }

static float noise(float3 p) {
  float3 a = floor(p);
  float3 d = p - a;
  d = d * d * (3.0 - 2.0 * d);

  float4 b = a.xxyy + float4(0.0, 1.0, 0.0, 1.0);
  float4 k1 = perm(b.xyxy);
  float4 k2 = perm(k1.xyxy + b.zzww);

  float4 c = k2 + a.zzzz;
  float4 k3 = perm(c);
  float4 k4 = perm(c + 1.0);

  float4 o1 = fract(k3 * (1.0 / 41.0));
  float4 o2 = fract(k4 * (1.0 / 41.0));

  float4 o3 = o2 * d.z + o1 * (1.0 - d.z);
  float2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

  return o4.y * d.y + o4.x * (1.0 - d.y);
}

static float SDF(float3 point, float iTime) {
  float3 p = float3(point.xy, iTime * 0.3 + point.z);
  float n = (noise(p) + noise(p * 2.0) * 0.5 + noise(p * 4.0) * 0.25) * 0.57;
  return length(point) - 0.35 - n * 0.3;
}

static float3 getNormal(float3 point, float iTime) {
  float2 e = float2(0.002, 0.0);
  return normalize(SDF(point, iTime) - float3(SDF(point - e.xyy, iTime),
                                              SDF(point - e.yxy, iTime),
                                              SDF(point - e.yyx, iTime)));
}

static float specularBlinnPhong(float3 light_dir, float3 ray_dir,
                                float3 normal) {
  float3 halfway = normalize(light_dir + ray_dir);
  return max(0.0, dot(normal, halfway));
}

static Hit raymarch(float3 p, float3 d, float iTime) {
  Hit hit;
  hit.dist = 0.0;
  hit.closest_dist = MAX_DISTANCE;

  for (int i = 0; i < MAX_RAY_MARCH_STEPS; ++i) {
    float sdf = SDF(p, iTime);
    p += d * sdf;
    hit.closest_dist = min(hit.closest_dist, sdf);
    hit.dist += sdf;
    if (hit.dist >= MAX_DISTANCE || abs(sdf) <= SURFACE_DISTANCE)
      break;
  }

  hit.p = p;
  return hit;
}

// 顶点着色器
vertex VertexOut glowyOrbVertex(uint vertexID [[vertex_id]]) {
  const float2 positions[3] = {
      float2(-1.0, -1.0),
      float2(3.0, -1.0),
      float2(-1.0, 3.0),
  };
  const float2 uvs[3] = {
      float2(0.0, 0.0),
      float2(2.0, 0.0),
      float2(0.0, 2.0),
  };

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = uvs[vertexID];
  return out;
}

// 片段着色器
fragment float4 glowyOrbFragment(VertexOut in [[stage_in]],
                                 constant GlowyOrbParams &params
                                 [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float iTime = params.time;
  float2 fragCoord = in.uv * iResolution;

  float2 uv = (fragCoord * 2.0 - iResolution) / iResolution.y;
  float4 fragColor = float4(0, 0, 0, 1);

  float3 pos = float3(0, 0, -1);
  float3 dir = normalize(float3(uv, 1));

  Hit hit = raymarch(pos, dir, iTime);

  // Glow effect
  float3 glowColor =
      pow(max(0.0, 1.0 - hit.closest_dist), 32.0) *
      (max(0.0, dot(uv, float2(0.707))) * float3(0.3, 0.65, 1.0) +
       max(0.0, dot(uv, float2(-0.707))) * float3(0.6, 0.35, 1.0) +
       float3(0.4, 0.5, 1.0));
  fragColor = float4(glowColor, 1.0);

  if (hit.closest_dist >= SURFACE_DISTANCE)
    return fragColor;

  float3 normal = getNormal(hit.p, iTime);
  float3 ray_dir = normalize(pos - hit.p);

  // Multiple colored lights
  float3 surfaceColor = float3(0.0);

  float facing = max(0.0, sqrt(dot(normal, float3(0.707, 0.707, 0))) * 1.5 -
                              dot(normal, -dir));
  surfaceColor +=
      mix(float3(0), float3(0.3, 0.65, 1.0), 0.75 * facing * facing * facing);

  facing = max(0.0, sqrt(dot(normal, float3(-0.707, -0.707, 0))) * 1.5 -
                        dot(normal, -dir));
  surfaceColor +=
      mix(float3(0), float3(0.6, 0.35, 1.0), 0.75 * facing * facing * facing);

  facing = max(0.0, sqrt(dot(normal, float3(0.0, 0.0, -1.0))) * 1.5 -
                        dot(normal, -dir));
  surfaceColor +=
      mix(float3(0), float3(0.4, 0.5, 1.0), 0.5 * facing * facing * facing);

  // Specular highlights
  surfaceColor +=
      mix(float3(0), float3(0.4, 0.625, 1.0),
          pow(specularBlinnPhong(normalize(float3(600, 800, -500) - hit.p),
                                 ray_dir, normal),
              12.0) *
              1.0);

  surfaceColor +=
      mix(float3(0), float3(0.6, 0.5625, 1.0),
          pow(specularBlinnPhong(normalize(float3(-600, -800, 0) - hit.p),
                                 ray_dir, normal),
              16.0) *
              0.75);

  surfaceColor = pow(surfaceColor, float3(1.25));

  return float4(surfaceColor, 1.0);
}
