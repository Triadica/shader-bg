// Sine Mountains - 正弦山脉风景效果
// License - CC0 or use as you wish
// 包含火车、树木、山脉和水面倒影的动态风景
// Forked from https://www.shadertoy.com/view/4lKcDD

#include <metal_stdlib>
using namespace metal;

#define PI 3.14159265359
#define TWO_PI (2.0 * PI)
#define HASHSCALE1 443.8975

// 颜色常量
constant float3 white = float3(0xdc, 0xe0, 0xd1) / float(0xff);
constant float3 dark = float3(0x1a, 0x13, 0x21) / float(0xff);
constant float3 bluebg = float3(0x00, 0x19, 0x5e) / float(0xff);
constant float3 colsun = float3(0x07, 0xaf, 0x81) / float(0xff);
constant float3 white2 = float3(0xec, 0xe8, 0x9e) / float(0xff);
constant float3 l1 = float3(0x07, 0x27, 0x21) / float(0xff);
constant float3 l2 = float3(0x00, 0x6c, 0xae) / float(0xff);
constant float3 l3 = float3(0x00, 0x48, 0x7f) / float(0xff);
constant float3 treecol = float3(0x12, 0x19, 0x27) / float(0xff);
constant float3 watercol = float3(0xcf, 0xe5, 0xf2) / float(0xff);
constant float3 traincol = float3(0x00, 0x6a, 0xb9) / float(0xff);
constant float3 trainlcol = float3(0xef, 0xe8, 0x95) / float(0xff);

float xRandom(float x) { return fmod(x * 7241.6465 + 2130.465521, 64.984131); }

float mfunc(float x, float xx, float yy) {
  x /= 0.20 * PI;
  x = fmod(x * 2.0, 2.8) - 1.195;
  x *= 19.0 * PI;
  return abs(8.0 + abs(-19.15 +
                       abs(-15.0 + yy +
                           abs(-12.25 - yy +
                               abs(-18.0 + xx +
                                   abs(-15.0 - xx + abs(0.95 * x + 4.0))))))) /
         100.0;
}

float hash2(float2 p) {
  float2 v1 = float2(sin(p.x * 591.32 + p.y * 154.077),
                     cos(p.x * 391.32 + p.y * 49.077));
  return fract(v1.x * v1.y);
}

float noise2(float y, float t) {
  float2 fl = floor(float2(y, t));
  float2 fr = fract(float2(y, t));
  float a =
      mix(hash2(fl + float2(0.0, 0.0)), hash2(fl + float2(1.0, 0.0)), fr.x);
  float b =
      mix(hash2(fl + float2(0.0, 1.0)), hash2(fl + float2(1.0, 1.0)), fr.x);
  return mix(a, b, fr.y);
}

float line(float2 uv, float width, float center) {
  return (1.0 - smoothstep(0.0, width / 2.0, abs(uv.y - center)));
}

float circle(float2 uv, float r1, float r2, bool disk, float2 resolution) {
  float w = 2.0 / resolution.y; // Approximate fwidth
  float t = r1 - r2;
  float r = r1;

  if (!disk)
    return smoothstep(-w / 2.0, w / 2.0, abs(length(uv) - r) - t / 2.0);
  else
    return smoothstep(-w / 3.0, w / 3.0, length(uv) - r);
}

float circle2(float2 uv, float r1, float r2, bool disk, float2 resolution) {
  float w = 2.0 / resolution.y; // Approximate fwidth
  float t = r1 - r2;
  float r = r1;
  if (!disk)
    return smoothstep(-w / 2.0, w / 2.0, abs(length(uv) - r) - t / 2.0);
  else
    return smoothstep(-w / 3.0, 1.05 + w / 3.0, length(uv) - r);
}

float w1(float x, float iTime) {
  x += -0.45;
  float modTime = fmod(iTime + 150.1, 310.0);
  if (modTime > 150.0)
    return 1.5 + 10.15 * mfunc(x * 0.7,
                               -80.0 * cos(0.5 + fmod(0.0 / 150.0 + 1.0, 3.0)),
                               0.0);
  else if (modTime > 5.0)
    return 1.5 +
           10.15 * mfunc(x * 0.7,
                         -80.0 * cos(0.5 +
                                     fmod((modTime - 5.0) / 140.0 + 1.0, 3.0)),
                         0.0);
  else
    return 1.5 + 10.15 * mfunc(x * 0.7,
                               -80.0 * cos(0.5 + fmod(0.0 / 140.0 + 1.0, 3.0)),
                               0.0);
}

float layer(float2 uv, float iTime) {
  float modTime = fmod(iTime + 150.1, 310.0);
  float2 ouv = uv;
  uv *= 0.5;
  if (modTime > 150.0)
    uv.x += (modTime - 150.0) / 200.0;
  uv.x += 50.0;
  uv.y += -0.21;
  float Amplitude1 = w1(uv.x, iTime);
  float2 p = uv;
  float Light_Track =
      line(float2(p.x, p.y * 1.5 + (Amplitude1 - 0.5) * 0.12), 0.005, 0.0);

  if (modTime < 150.0)
    return Light_Track * smoothstep(0.0, 5.0, modTime);
  else if (modTime < 300.0)
    return Light_Track * smoothstep(150.0, 155.0, modTime);
  else
    return Light_Track * smoothstep(305.0, 300.0, modTime);
}

float shape(float2 uv, int N, float radius_in, float radius_out, float zoom,
            float2 resolution) {
  float a = atan2(uv.x, uv.y) + PI;
  float rx = TWO_PI / float(N);
  float d = cos(floor(0.5 + a / rx) * rx - a) * length(uv);
  float width = (2.0 + 1.2 * zoom) / resolution.y;
  float color = smoothstep(0.44, 0.44 + width, abs(d - radius_in) + radius_out);
  return (1.0 - color);
}

float msine(float2 uv) {
  float heightA = 0.025;
  float heightB = 0.025;
  float heightC = 0.013;
  uv.y = sin((uv.x + 1.0) * 5.0) * heightA;
  uv.y = uv.y + sin((uv.x + 0.0 / 5.0) * 3.0) * heightB;
  uv.y = uv.y + sin((uv.x + 1.0) * 2.0) * heightC;
  return uv.y;
}

float hash11(float p) {
  float3 p3 = fract(float3(p) * HASHSCALE1);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(float p) {
  float i = floor(p);
  float f = fract(p);
  float t = f * f * (3.0 - 2.0 * f);
  return mix(f * hash11(i), (f - 1.0) * hash11(i + 1.0), t);
}

float fbm(float x, float persistence, int octaves) {
  float total = 0.0;
  float maxValue = 0.0;
  float amplitude = 1.0;
  float frequency = 1.0;
  for (int i = 0; i < octaves; ++i) {
    total += noise(x * frequency) * amplitude;
    maxValue += amplitude;
    amplitude *= persistence;
    frequency *= 2.0;
  }
  return (total / maxValue);
}

float msine2(float2 uv) { return (fbm(uv.x / 10.0, 0.25, 4) * 20.0 + 0.5); }

float trees(float2 uv, float iTime, float2 resolution) {
  float zoom = 10.0;
  uv.x += iTime / 35.0;
  uv *= zoom;
  float2 tuvy =
      float2(0.0, 8.0 * msine(float2(floor(uv.x / 0.38), uv.y) / zoom));
  float rval = xRandom(floor(uv.x / 0.38));
  float d = 0.0;

  if (rval > 85.0 * fract(cos(rval)) + 85.0 * sin(rval)) {
    rval = max(1.0, 2.5 * abs(sin(rval)));
    uv.x = fmod(uv.x, 0.38) - 0.19;
    uv += tuvy;
    uv *= rval;
    float xval = 1.2 * sin(xRandom(tuvy.y)) * 0.19 * (1.25 - rval);
    uv.y += 0.75 / rval;
    uv.x += xval;
    float2 ouv_trees = uv;
    uv.y *= 0.85;
    d = shape(uv, 3, -0.380, 0.0, zoom + rval, resolution);
    uv.y += 0.12;
    uv.y *= 0.75;
    d = max(d, shape(uv, 3, -0.370, 0.0, zoom + rval, resolution));
    uv.y += 0.1;
    uv.y *= 1.2;
    d = max(d, shape(uv, 3, -0.3650, 0.0, zoom + rval, resolution));
    d = max(d, smoothstep(0.02 + (2.0 + 1.2 * (zoom + rval)) / resolution.y,
                          0.02, abs(uv.x)) *
                   step(ouv_trees.y, 0.0)) *
        step(-0.75 + 0.12 * (2.5 - rval), ouv_trees.y);
  }
  return d;
}

float treex(float2 uv, float iTime, float2 resolution) {
  uv.y += 0.08;
  return trees(uv, iTime, resolution);
}

float layer_bghills(float2 uv, float iTime, float2 resolution) {
  uv.x += iTime / 35.0;
  float hillHeight = msine(uv / 0.38 - 0.038) * 10.0 + uv.y * 10.0 + 1.6;
  
  // 原始 GLSL: smoothstep(0.5 + 20/res, 0.5, hillHeight)
  // 当 edge0 > edge1 时，GLSL 的 smoothstep 行为：
  //   - hillHeight <= edge1 (0.5) → 返回 1.0
  //   - hillHeight >= edge0 (0.5 + 20/res) → 返回 0.0
  //   - 中间平滑插值从 1.0 到 0.0
  // 
  // Metal 实现：手动计算 clamp((edge1 - hillHeight)/(edge1 - edge0), 0, 1)
  float edge0 = 0.5 + 20.0 / resolution.y;
  float edge1 = 0.5;
  float t = clamp((hillHeight - edge1) / (edge0 - edge1), 0.0, 1.0);
  float d = 1.0 - (t * t * (3.0 - 2.0 * t));  // smoothstep 的插值公式
  return d;
}

float trees2(float2 uv, float iTime, float2 resolution) {
  float zoom = 10.0;
  uv.x += iTime / 45.0;
  uv *= zoom;
  float2 tuvy = float2(0.0, 0.2 * msine2(float2(floor(uv.x / 0.38), uv.y)));
  float rval = xRandom(floor(uv.x / 0.38));
  float d = 0.0;

  if (rval > 55.0 * fract(cos(rval)) + 85.0 * sin(rval)) {
    rval = max(1.5, 2.5 * abs(sin(rval)));
    uv.x = fmod(uv.x, 0.38) - 0.19;
    uv += tuvy;
    uv *= rval;
    float xval = -1.2 * sin(xRandom(tuvy.y)) * 0.19 * (1.25 - rval);
    uv.y += -0.25 / rval;
    uv.x += xval;
    float2 ouv_trees2 = uv;
    uv.y *= 0.85;
    d = shape(uv, 3, -0.380, 0.0, zoom + rval, resolution);
    uv.y += 0.12;
    uv.y *= 0.75;
    d = max(d, shape(uv, 3, -0.370, 0.0, zoom + rval, resolution));
    uv.y += 0.1;
    uv.y *= 1.2;
    d = max(d, shape(uv, 3, -0.3650, 0.0, zoom + rval, resolution));
    d = max(d, smoothstep(0.02 + (2.0 + 1.2 * (zoom + rval)) / resolution.y,
                          0.02, abs(uv.x)) *
                   step(ouv_trees2.y, 0.0)) *
        step(-0.75 + 0.12 * (2.5 - rval), ouv_trees2.y);
  }
  return d;
}

float treex2(float2 uv, float iTime, float2 resolution) {
  uv.x += 1.2;
  uv.y += 0.08;
  return trees2(uv, iTime, resolution);
}

float layer_bghills2(float2 uv, float iTime, float2 resolution) {
  uv.x += 1.2;
  uv.x += iTime / 45.0;
  float hillHeight =
      0.2 * msine2((uv * 10.0) / 0.38 - 0.038) + uv.y * 11.0 + 0.86;
  
  // 原始 GLSL: smoothstep(-0.1555 + 8/res, -0.1555, hillHeight)
  // 当 edge0 > edge1 时，GLSL 的 smoothstep 行为：
  //   - hillHeight <= edge1 (-0.1555) → 返回 1.0
  //   - hillHeight >= edge0 (-0.1555 + 8/res) → 返回 0.0
  //   - 中间平滑插值从 1.0 到 0.0
  // 
  // Metal 实现：手动计算
  float edge0 = -0.1555 + 8.0 / resolution.y;
  float edge1 = -0.1555;
  float t = clamp((hillHeight - edge1) / (edge0 - edge1), 0.0, 1.0);
  float d = 1.0 - (t * t * (3.0 - 2.0 * t));  // smoothstep 的插值公式
  return d;
}

float3 undw(float2 uv, float3 tc, float iTime, float2 resolution) {
  float2 res = resolution / resolution.y;
  uv.x += iTime / 10.0;
  uv += res / 2.0;
  uv.y = 1.0 - uv.y;
  uv.y += -0.759;
  uv.x *= 0.5;
  uv *= 5.3;
  float y_off = sin(2.0 * uv.y + 0.0 * iTime / 1.73);
  float vy = (uv.y +
              (floor(5.0 - (uv.y + 2.75) / 0.52) / 5.0) *
                  sin(uv.x * 6.28318 + y_off) * 0.1 -
              0.05);
  float c =
      (smoothstep(0.0, 1.0, fmod(vy * 5.0, 1.0) * 4.2) + floor(vy * 5.0)) / 5.0;
  float2 uv_d = float2(uv.x * 0.3 + y_off * 0.01, c);
  float3 fragColor;
  float3 gamma = tc;
  fragColor.r = pow(c, 1.0 / gamma.r);
  fragColor.g = pow(c, 1.0 / gamma.g);
  fragColor.b = pow(c, 1.0 / gamma.b);
  fragColor.rgb *= tc * (-noise2(uv_d.x, uv_d.y) * 0.3 + 0.7);
  return max(float3(0.0), fragColor);
}

float trainx(float2 uv, float2 resolution) {
  uv.y += 0.325;
  float d = 1.0 - circle(uv, 0.11, 0.0, true, resolution);
  float stval = step(0.07, uv.y);
  d *= stval;
  d = max(d, step(-0.5, uv.x) * step(uv.x, 0.0) * step(uv.y, 0.109)) * stval;
  d = max(d, 1.0 - circle(uv + float2(0.5, 0.0), 0.11, 0.0, true, resolution)) *
      stval;
  return d;
}

float trainxl(float2 uv, float2 resolution) {
  uv.y += 0.3;
  uv.y += -0.07;
  float2 ouv = uv;
  uv.x = fmod(uv.x, 0.01) - 0.005;
  float d = smoothstep(0.0045 + 2.0 / resolution.y, 0.0025, abs(uv.x));
  d *= step(abs(uv.y), 0.0025);
  uv.x = ouv.x;
  uv.x = fmod(uv.x, 0.15) - 0.005;
  d *= step(abs(uv.x), 0.0025 * 50.0);
  d *= step(ouv.x, -0.05);
  d *= step(-0.50, ouv.x);
  d += smoothstep(0.0110 + 2.0 / resolution.y, 0.01, abs(ouv.x + 0.021)) *
       step(abs(uv.y), 0.0025);
  d += smoothstep(0.025 + 2.0 / resolution.y, 0.024, abs(ouv.x - 0.035)) *
       step(abs(uv.y), 0.0025);
  return d;
}

kernel void sineMountainsCompute(texture2d<float, access::write> output
                                 [[texture(0)]],
                                 constant float &time [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]]) {
  float2 resolution = float2(output.get_width(), output.get_height());
  float2 fragCoord = float2(gid);

  // 减慢时间到 1/4
  float iTime = time * 0.25;

  // 翻转 Y 轴以匹配 GLSL 坐标系统
  fragCoord.y = resolution.y - fragCoord.y;

  float2 res = resolution / resolution.y;
  float2 uv = fragCoord / resolution.y - res / 2.0;

  float b = 1.0 - circle(uv - 0.21, 0.1242, 0.22, true, resolution);
  float3 col = bluebg;
  float b1 = 1.0 - circle2(uv - 0.21, 0.1242, 0.22, true, resolution);
  float b2 = smoothstep(-1.0, -0.05, uv.y);

  float lx1 = layer(uv + float2(0.0, -0.152), iTime);
  col = col - lx1 * l1 * b1;
  col += b1 * colsun;
  col = mix(col, white2, min(b, 1.0 - lx1));

  col = mix(col, l2 * b1,
            layer_bghills2(uv + float2(0.0, -0.05), iTime, resolution));
  col = mix(col, 3.0 * treecol * b1,
            treex2(uv + float2(0.0, -0.05), iTime, resolution));
  col = mix(col, l3 * b1,
            layer_bghills(uv + float2(0.0, 0.0), iTime, resolution));
  col = mix(col, treecol * b1, treex(uv + float2(0.0, 0.0), iTime, resolution));

  float3 toplvlcol2 = float3(0.0);
  if (uv.y < -0.25)
    toplvlcol2 = undw(uv, watercol, iTime, resolution);

  float water_mask = step(uv.y, -0.25);
  col = mix(col, toplvlcol2 + 0.42 * b2 * l2, water_mask);

  float2 uv_train = uv;
  uv_train.x += 0.3 * sin(0.5 * sin(iTime / 8.0) + cos(iTime / 10.0));
  float trx = trainx(uv_train, resolution);
  col = mix(col, traincol * b1, trx * (1.0 - water_mask));
  col = mix(col, trainlcol, trainxl(uv_train, resolution) * trx);

  output.write(float4(col, 1.0), gid);
}
