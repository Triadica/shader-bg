// Forked from https://www.shadertoy.com/view/NsGfDW

#include <metal_stdlib>
using namespace metal;

struct MovingPixelsData {
  float time;
  float2 resolution;
  float2 padding;
};

// Hash function for cell height
static float moving_H(float2 p, float time) {
  return sin(time * 0.5 +
             fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453) * 10.0) *
             0.5 +
         0.5;
}

static float4 moving_pixels_effect(float2 fragCoord, float time,
                                   float2 resolution) {
  // 降低速度到 1/10
  float slowTime = time * 0.1;

  float2 r = resolution;
  float2 u = (fragCoord + fragCoord - r) / r.y * 5.0; // camera scaling
  float2 l = fract(u);                                // cell local coordinates
  u = floor(u);                                       // cell id

  float h = moving_H(u, slowTime); // cell "height"
  float d = 1.0;
  float n, f;
  float2 s, z;

  // calculate distance field to 8 neighbors cells
  for (int i = 0; i < 9; i++) {
    s = float2(float(i / 3), float(i % 3)) - 1.0; // cell id shift
    z = abs(l - 0.5 - s) - 0.5; // the distance to the neighbor cell

    // divided by the height difference with the current cell
    n = (length(max(z, 0.0)) + min(max(z.x, z.y), 0.0)) /
        max(moving_H(u + s, slowTime) - h, 0.05) / 2.0;
    // more difference -> less distance -> darker shadow

    f = max(0.0, 1.0 - abs(n - d) / 0.4);       // smooth min of distance
    d = (i != 4) ? min(d, n) - 0.1 * f * f : d; // skipping current cell
  }

  float4 color1 = float4(0.4, 0.5, 0.6, 1.0);
  float4 color2 = float4(1.0, 0.9, 0.6, 1.0);

  float4 col = mix(color1, color2, h) + min(d, 0.2) - 0.3;

  return col;
}

kernel void movingPixelsCompute(texture2d<float, access::write> output
                                [[texture(0)]],
                                constant MovingPixelsData &data [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = data.resolution;
  float2 fragCoord = float2(gid);

  float4 col = moving_pixels_effect(fragCoord, data.time, resolution);

  output.write(col, gid);
}
