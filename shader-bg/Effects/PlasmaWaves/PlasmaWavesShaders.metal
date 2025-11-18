//
//  PlasmaWavesShaders.metal
//  shader-bg
//
//  Based on Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
//  License https://creativecommons.org/licenses/by-nc-sa/3.0/deed.en_US
//  Forked from https://www.shadertoy.com/view/ltXczj

#include <metal_stdlib>
using namespace metal;

struct PlasmaWavesData {
  float time;
  float2 resolution;
  float2 padding;
};

// Constants
constant float overallSpeed = 0.2;
constant float gridSmoothWidth = 0.015;
constant float axisWidth = 0.05;
constant float majorLineWidth = 0.025;
constant float minorLineWidth = 0.0125;
constant float majorLineFrequency = 5.0;
constant float minorLineFrequency = 1.0;
constant float4 gridColor = float4(0.5);
constant float scale = 5.0;
constant float4 lineColor = float4(0.25, 0.5, 1.0, 1.0);
constant float minLineWidth = 0.02;
constant float maxLineWidth = 0.5;
constant float lineSpeed = 1.0 * overallSpeed;
constant float lineAmplitude = 1.0;
constant float lineFrequency = 0.2;
constant float warpSpeed = 0.2 * overallSpeed;
constant float warpFrequency = 0.5;
constant float warpAmplitude = 1.0;
constant float offsetFrequency = 0.5;
constant float offsetSpeed = 1.33 * overallSpeed;
constant float minOffsetSpread = 0.6;
constant float maxOffsetSpread = 2.0;
constant int linesPerGroup = 16;

// Background colors
float4 getBgColor(int index) {
  if (index == 0) {
    return lineColor * 0.5;
  } else {
    return lineColor - float4(0.2, 0.2, 0.7, 1.0);
  }
}

float drawCircle(float2 pos, float radius, float2 coord) {
  return smoothstep(radius + gridSmoothWidth, radius, length(coord - pos));
}

float drawSmoothLine(float pos, float halfWidth, float t) {
  return smoothstep(halfWidth, 0.0, abs(pos - t));
}

float drawCrispLine(float pos, float halfWidth, float t) {
  return smoothstep(halfWidth + gridSmoothWidth, halfWidth, abs(pos - t));
}

float drawPeriodicLine(float freq, float width, float t) {
  return drawCrispLine(freq / 2.0, width, abs(fmod(t, freq) - freq / 2.0));
}

float drawGridLines(float axis) {
  return drawCrispLine(0.0, axisWidth, axis) +
         drawPeriodicLine(majorLineFrequency, majorLineWidth, axis) +
         drawPeriodicLine(minorLineFrequency, minorLineWidth, axis);
}

float drawGrid(float2 space) {
  return min(1.0, drawGridLines(space.x) + drawGridLines(space.y));
}

// Pseudo-random function using fourier transform
float random(float t) {
  return (cos(t) + cos(t * 1.3 + 1.3) + cos(t * 1.4 + 1.4)) / 3.0;
}

float getPlasmaY(float x, float horizontalFade, float offset, float time) {
  return random(x * lineFrequency + time * lineSpeed) * horizontalFade *
             lineAmplitude +
         offset;
}

kernel void plasmaWavesShader(texture2d<float, access::write> output
                              [[texture(0)]],
                              constant PlasmaWavesData &data [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]]) {
  float2 fragCoord = float2(gid);
  float2 iResolution = data.resolution;
  float iTime = data.time;

  float2 uv = fragCoord / iResolution;
  float2 space = (fragCoord - iResolution / 2.0) / iResolution.x * 2.0 * scale;

  float horizontalFade = 1.0 - (cos(uv.x * 6.28) * 0.5 + 0.5);
  float verticalFade = 1.0 - (cos(uv.y * 6.28) * 0.5 + 0.5);

  // Fun with nonlinear transformations! (wind / turbulence)
  space.y += random(space.x * warpFrequency + iTime * warpSpeed) *
             warpAmplitude * (0.5 + horizontalFade);
  space.x += random(space.y * warpFrequency + iTime * warpSpeed + 2.0) *
             warpAmplitude * horizontalFade;

  float4 lines = float4(0.0);

  for (int l = 0; l < linesPerGroup; l++) {
    float normalizedLineIndex = float(l) / float(linesPerGroup);
    float offsetTime = iTime * offsetSpeed;
    float offsetPosition = float(l) + space.x * offsetFrequency;
    float rand = random(offsetPosition + offsetTime) * 0.5 + 0.5;
    float halfWidth =
        mix(minLineWidth, maxLineWidth, rand * horizontalFade) / 2.0;
    float offset =
        random(offsetPosition + offsetTime * (1.0 + normalizedLineIndex)) *
        mix(minOffsetSpread, maxOffsetSpread, horizontalFade);
    float linePosition = getPlasmaY(space.x, horizontalFade, offset, iTime);
    float line = drawSmoothLine(linePosition, halfWidth, space.y) / 2.0 +
                 drawCrispLine(linePosition, halfWidth * 0.15, space.y);

    float circleX = fmod(float(l) + iTime * lineSpeed, 25.0) - 12.0;
    float2 circlePosition =
        float2(circleX, getPlasmaY(circleX, horizontalFade, offset, iTime));
    float circle = drawCircle(circlePosition, 0.01, space) * 4.0;

    line = line + circle;
    lines += line * lineColor * rand;
  }

  float4 fragColor = mix(getBgColor(0), getBgColor(1), uv.x);
  fragColor *= verticalFade;
  fragColor.a = 1.0;

  // Debug grid (commented out):
  // fragColor = mix(fragColor, gridColor, drawGrid(space));

  fragColor += lines;

  output.write(fragColor, gid);
}
