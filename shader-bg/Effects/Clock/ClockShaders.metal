//
//  ClockShaders.metal
//  shader-bg
//
//  Created on 2025-10-31.
//
//  Adapted from "Clock" by Inigo Quilez (https://www.shadertoy.com/view/wdX3Rr)
//  Shared under the educational-use terms described by the author. Please
//  retain attribution if this code or visual output is redistributed.
//  Forked from https://www.shadertoy.com/view/lsXGz8
//

#include <metal_stdlib>
using namespace metal;

struct ClockParams {
  float2 resolution;
  float seconds;
  float minutes;
  float hours;
  float fractionalSecond;
  float3 padding;
};

struct ClockVertexOut {
  float4 position [[position]];
  float2 uv;
};

vertex ClockVertexOut clockVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  ClockVertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

inline float sdLine(float2 p, float2 a, float2 b) {
  float2 pa = p - a;
  float2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0f, 1.0f);
  return length(pa - ba * h);
}

inline float3 line(float3 buf, float2 a, float2 b, float2 p, float2 w,
                   float4 col) {
  float f = sdLine(p, a, b);
  float g = fwidth(f) * w.y;
  float factor = col.w * (1.0f - smoothstep(w.x - g, w.x + g, f));
  return mix(buf, col.xyz, factor);
}

inline float3 hash3(float n) {
  float3 s = sin(float3(n, n + 1.0f, n + 2.0f)) * 43758.5453123f;
  return fract(s);
}

fragment float4 clockFragment(ClockVertexOut in [[stage_in]],
                              constant ClockParams &params [[buffer(0)]]) {
  constexpr float kPi = 3.14159265358979323846f;
  constexpr float kTau = 6.28318530717958647693f;

  float2 fragCoord = in.uv * params.resolution;
  float minDim = fmin(params.resolution.x, params.resolution.y);
  float2 uv = (fragCoord * 2.0f - params.resolution) / minDim;

  uv *= 2.0f; // to make clock smaller in the view

  float r = length(uv);
  float a = atan2(uv.y, uv.x) + kPi;

  float mils = params.fractionalSecond;
  float secs = params.seconds + smoothstep(0.9f, 1.0f, mils);
  float mins = params.minutes;
  float hors = params.hours;

  float3 col = float3(0.0f);

  // Inner watch body
  {
    float d = r - 0.94f;
    if (d > 0.0f) {
      col *= 1.0f - 0.5f / (1.0f + 32.0f * d);
    }
    col = mix(col, float3(0.05f), 1.0f - smoothstep(0.0f, 0.01f, d));
  }

  // 5 minute marks
  float f = fabs(2.0f * fract(0.5f + a * 60.0f / kTau) - 1.0f);
  float g =
      1.0f - smoothstep(0.0f, 0.1f,
                        fabs(2.0f * fract(0.5f + a * 12.0f / kTau) - 1.0f));
  float w = fwidth(f);
  f = 1.0f - smoothstep(0.1f * g + 0.05f - w, 0.1f * g + 0.05f + w, f);
  f *= smoothstep(0.85f, 0.86f, r + 0.05f * g) - smoothstep(0.94f, 0.95f, r);
  col = mix(col, float3(1.0f), f);

  // Seconds hand shadow and body
  float2 dir = float2(sin(kTau * secs / 60.0f), cos(kTau * secs / 60.0f));
  float4 handColor = float4(0.78f, 0.84f, 1.0f, 0.85f);

  col = line(col, -dir * 0.15f, dir * 0.7f, uv + 0.015f, float2(0.005f, 8.0f),
             float4(0.0f, 0.0f, 0.0f, 0.35f));
  col =
      line(col, -dir * 0.15f, dir * 0.7f, uv, float2(0.005f, 1.0f), handColor);

  // Minutes hand shadow and body
  dir = float2(sin(kTau * mins / 60.0f), cos(kTau * mins / 60.0f));
  col = line(col, -dir * 0.15f, dir * 0.7f, uv + 0.015f, float2(0.015f, 8.0f),
             float4(0.0f, 0.0f, 0.0f, 0.35f));
  col =
      line(col, -dir * 0.15f, dir * 0.7f, uv, float2(0.015f, 1.0f), handColor);

  // Hours hand shadow and body
  dir = float2(sin(kTau * hors / 12.0f), cos(kTau * hors / 12.0f));
  col = line(col, -dir * 0.15f, dir * 0.4f, uv + 0.015f, float2(0.015f, 8.0f),
             float4(0.0f, 0.0f, 0.0f, 0.35f));
  col =
      line(col, -dir * 0.15f, dir * 0.4f, uv, float2(0.015f, 1.0f), handColor);

  // Center mini circle
  {
    float d = r - 0.035f;
    if (d > 0.0f) {
      col *= 1.0f - 0.5f / (1.0f + 64.0f * d);
    }
    col = mix(col, float3(0.85f), 1.0f - smoothstep(0.035f, 0.038f, r));
    col = mix(col, float3(0.6f),
              1.0f - smoothstep(0.0f, 0.007f, fabs(r - 0.038f)));
  }

  // Dithering
  col += (1.0f / 255.0f) * hash3(uv.x + 13.0f * uv.y);

  return float4(col, 1.0f);
}
