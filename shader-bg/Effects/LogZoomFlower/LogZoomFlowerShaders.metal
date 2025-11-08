#include <metal_stdlib>
using namespace metal;

struct LogZoomFlowerData {
  float time;
  float2 resolution;
  float2 padding;
};

#define LOGZOOM_TAU (atan(1.0) * 8.0)

static float logzoom_distanceToLogSpirals(float2 p, float a, float b,
                                          float arms) {
  const float tau = LOGZOOM_TAU;
  float R = length(p);
  float phi = atan2(p.y, p.x);
  int nArms = int(floor(arms + 0.5));
  float minDist = 1e26;

  for (int i = 0; i < 64; ++i) {
    if (i >= nArms)
      break;
    float phi_i = phi - tau * float(i) / float(nArms);
    float n_float = (log(R / a) / b - phi_i) / tau;
    float n_floor = floor(n_float);
    float n_ceil = ceil(n_float);
    float distMinArm = 1e20;

    for (int k = 0; k < 2; ++k) {
      float n_int = (k == 0) ? n_floor : n_ceil;
      if (n_floor == n_ceil && k == 1)
        break;
      float theta = phi_i + tau * n_int;

      for (int j = 0; j < 4; ++j) {
        float phi_theta = phi_i - theta;
        float sin_phi_theta = sin(phi_theta);
        float cos_phi_theta = cos(phi_theta);
        float bae = b * a * exp(b * theta);
        float h = bae - R * (b * cos_phi_theta + sin_phi_theta);
        float hd = b * bae - R * (b * sin_phi_theta - cos_phi_theta);
        if (abs(hd) < 1e-6)
          break;
        theta -= h / hd;
      }

      float r = a * exp(b * theta);
      float cosD = cos(phi_i - theta);
      float d2 = R * R + r * r - 2.0 * R * r * cosD;
      if (d2 < 0.0)
        d2 = 0.0;
      float dist = sqrt(d2);
      if (dist < distMinArm)
        distMinArm = dist;
    }

    if (distMinArm < minDist)
      minDist = distMinArm;
  }

  return minDist;
}

static float4 logzoom_effect(float2 fragCoord, float time, float2 resolution) {
  // 降低缩放速度到 1/10
  float zoOM = exp2(fmod(time * 0.1, 14.0));
  float2 p = (1.0 / zoOM) * (fragCoord - resolution / 2.0) /
             min(resolution.y, resolution.x);

  float dist = 1e20;
  dist = logzoom_distanceToLogSpirals(p, 1.0, 0.9, 7.0);
  dist = max(dist, logzoom_distanceToLogSpirals(p, 1.0, -0.9, 7.0));

  float3 col = float3(0.07 / dist / zoOM);
  col *= 1.0 - exp(-25.0 * zoOM * abs(dist));
  col *= float3(0.8, 0.7, 1.2);

  return float4(tanh(col), 1.0);
}

kernel void logZoomFlowerCompute(texture2d<float, access::write> output
                                 [[texture(0)]],
                                 constant LogZoomFlowerData &data [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = logzoom_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
