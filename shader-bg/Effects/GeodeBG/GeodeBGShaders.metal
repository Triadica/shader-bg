//
//  GeodeBGShaders.metal
//  shader-bg
//
//  Created on 2025-11-12.
//  Geode BG - Pastel Wave Layers
//  Inspired by geode crystal formations with flowing wave patterns
//  Forked from https://www.shadertoy.com/view/XX3SD7

#include <metal_stdlib>
using namespace metal;

struct GeodeBGParams {
  float time;
  float2 resolution;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// Vertex shader for full-screen triangle
vertex VertexOut geodeBGVertex(uint vertexID [[vertex_id]]) {
  VertexOut out;
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;
  return out;
}

fragment float4 geodeBGFragment(VertexOut in [[stage_in]],
                                constant GeodeBGParams &params [[buffer(0)]]) {
  float2 iResolution = params.resolution;
  float iTime = params.time;
  float2 fragCoord = in.texCoord * iResolution;

  // Wave configuration
  const int waveCount = 5;

  // Pastel wave colors - stored as RGB values
  float3 waveColour[5];
  waveColour[0] = float3(0.961, 0.682, 0.490); // Pastel light orange
  waveColour[1] = float3(0.925, 0.537, 0.486); // Pastel pinky orange
  waveColour[2] = float3(0.835, 0.412, 0.522); // Pastel pink
  waveColour[3] = float3(0.678, 0.329, 0.573); // Pastel purple
  waveColour[4] = float3(0.443, 0.290, 0.604); // Pastel bluey purple

  // Wave heights/offsets
  float waveOffset[5];
  waveOffset[0] = 0.8; // Top wave
  waveOffset[1] = 0.64;
  waveOffset[2] = 0.48;
  waveOffset[3] = 0.32;
  waveOffset[4] = 0.16; // Bottom wave

  // Wave parameters
  float waveAmplitude = 0.05;
  float waveLength = -10.0;
  float waveSlowdown = 3.0;
  float transitionSmoothness = 0.002;

  // Normalize coordinates from 0 to 1
  float2 uv = fragCoord.xy / iResolution.xy;

  // Background color (used at the top)
  float3 finalColour = float3(0.956, 0.831, 0.557);

  // Store all 25 sine waves (5 groups of 5)
  float sineWave[25];

  // Group 1
  sineWave[0] = waveAmplitude * 1.0 *
                sin(waveLength * 1.0 * uv.x + (iTime / waveSlowdown));
  sineWave[1] = waveAmplitude * 2.1 *
                sin(waveLength * 1.21 * uv.x + (iTime / waveSlowdown));
  sineWave[2] = waveAmplitude * 1.2 *
                sin(waveLength * 1.337 * uv.x + (iTime / waveSlowdown));
  sineWave[3] = waveAmplitude * 1.3 *
                sin(waveLength * 1.69 * uv.x + (iTime / waveSlowdown));
  sineWave[4] = waveAmplitude * 1.9 *
                sin(waveLength * 0.6 * uv.x + (iTime / waveSlowdown));

  // Group 2
  sineWave[5] = waveAmplitude * 2.2 *
                sin(waveLength * 1.2 * uv.x + (iTime / waveSlowdown / 2.0));
  sineWave[6] = waveAmplitude * 1.2 *
                sin(waveLength * 3.2 * uv.x + (iTime / waveSlowdown / 2.0));
  sineWave[7] = waveAmplitude * 2.1 *
                sin(waveLength * 0.75 * uv.x + (iTime / waveSlowdown / 2.0));
  sineWave[8] = waveAmplitude * 1.23 *
                sin(waveLength * 1.43 * uv.x + (iTime / waveSlowdown / 2.0));
  sineWave[9] = waveAmplitude * 0.22 *
                sin(waveLength * 0.56 * uv.x + (iTime / waveSlowdown / 2.0));

  // Group 3
  sineWave[10] = waveAmplitude * 1.3 *
                 cos(waveLength * 1.2 * uv.x + (iTime / waveSlowdown / 1.5));
  sineWave[11] = waveAmplitude * 1.7 *
                 cos(waveLength * 2.5 * uv.x + (iTime / waveSlowdown / 1.5));
  sineWave[12] = waveAmplitude * 1.1 *
                 cos(waveLength * 1.1 * uv.x + (iTime / waveSlowdown / 1.5));
  sineWave[13] = waveAmplitude * 1.43 *
                 cos(waveLength * 1.6 * uv.x + (iTime / waveSlowdown / 1.5));
  sineWave[14] = waveAmplitude * 2.3 *
                 cos(waveLength * 0.2 * uv.x + (iTime / waveSlowdown / 1.5));

  // Group 4
  sineWave[15] = waveAmplitude * 1.6 *
                 cos(waveLength * 2.54 * uv.x + (iTime / waveSlowdown / 3.0));
  sineWave[16] = waveAmplitude * 1.31 *
                 cos(waveLength * 1.02 * uv.x + (iTime / waveSlowdown / 3.0));
  sineWave[17] = waveAmplitude * 2.02 *
                 cos(waveLength * 0.92 * uv.x + (iTime / waveSlowdown / 3.0));
  sineWave[18] = waveAmplitude * 2.65 *
                 cos(waveLength * 0.43 * uv.x + (iTime / waveSlowdown / 3.0));
  sineWave[19] = waveAmplitude * 1.92 *
                 cos(waveLength * 0.2 * uv.x + (iTime / waveSlowdown / 3.0));

  // Group 5 (reversed direction with -iTime)
  sineWave[20] = waveAmplitude * 0.8 *
                 sin(waveLength * 1.52 * uv.x + (-iTime / waveSlowdown));
  sineWave[21] = waveAmplitude * 1.4 *
                 cos(waveLength * 0.97 * uv.x + (-iTime / waveSlowdown));
  sineWave[22] = waveAmplitude * 1.2 *
                 sin(waveLength * 1.23 * uv.x + (-iTime / waveSlowdown));
  sineWave[23] = waveAmplitude * 0.7 *
                 cos(waveLength * 0.83 * uv.x + (-iTime / waveSlowdown));
  sineWave[24] = waveAmplitude * 1.0 *
                 sin(waveLength * 1.00 * uv.x + (-iTime / waveSlowdown));

  // Create individual waves - each layer uses a different group of 5 waves
  for (int i = 0; i < waveCount; i++) {
    // Sum the 5 waves for this specific layer (group)
    float sum = 0.0;
    for (int j = 0; j < 5; j++) {
      sum += sineWave[i * 5 + j];
    }

    // Average the 5 waves and add the offset for this layer
    float finalWave = (sum / 5.0) + waveOffset[i];

    // Check if we're below the wave and blend the color
    if (uv.y < finalWave) {
      // Smooth transition between colors
      finalColour =
          mix(finalColour, waveColour[i],
              smoothstep(finalWave, finalWave - transitionSmoothness, uv.y));
    }
  }

  // Output to screen
  return float4(finalColour, 1.0);
}
