//
//  MoonTreeShaders.metal
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//  Based on "Moon Forest" shader from Shadertoy
//  Forked from https://www.shadertoy.com/view/wtdGWl

#include <metal_stdlib>
using namespace metal;

#define S(a, b, t) smoothstep(a, b, t)
#define LAYER_COUNT 10.0
#define MOON_SIZE 0.15
#define TREE_COL float3(0.8, 0.8, 1.0)
#define ORBIT_SPEED 0.025
#define SCROLL_SPEED 0.3
#define ROT -0.785398
#define ZOOM 0.4
#define STAR_SPEED 0.25

struct MoonTreeParams {
  float time;
  float2 resolution;
  float2 mouse;
  float padding;
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// 顶点着色器
vertex VertexOut moonTreeVertex(uint vertexID [[vertex_id]]) {
  float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0),
                         float2(-1.0, 3.0)};

  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = positions[vertexID] * 0.5 + 0.5;
  return out;
}

// Hash 函数
float moonTree_N11(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

float moonTree_N21(float2 p) {
  float3 p3 = fract(float3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// 计算点到线段的距离
float moonTree_DistLine(float2 p, float2 a, float2 b) {
  float2 pa = p - a;
  float2 ba = b - a;
  float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * t);
}

// 绘制线条
float moonTree_DrawLine(float2 p, float2 a, float2 b) {
  float d = moonTree_DistLine(p, a, b);
  float m = S(0.00125, 0.000001, d);
  float d2 = length(a - b);
  m *= S(1.0, 0.5, d2) + S(0.04, 0.03, abs(d2 - 0.75));
  return m;
}

// 流星
float moonTree_ShootingStar(float2 uv) {
  float2 gv = fract(uv) - 0.5;
  float2 id = floor(uv);

  float h = moonTree_N21(id);

  float line = moonTree_DrawLine(gv, float2(0.0, h), float2(0.1, h));
  float trail = S(0.12, 0.0, gv.x);

  return line * trail;
}

// 流星层
float moonTree_LayerShootingStars(float2 uv, float time) {
  float t = time * STAR_SPEED;
  float2 rv1 = float2(uv.x - t, uv.y + t);
  rv1.x *= 1.05;

  float r = 3.0 * ROT;
  float s = sin(r);
  float c = cos(r);
  float2x2 rot = float2x2(c, -s, s, c);
  rv1 = rot * rv1;
  rv1 *= ZOOM * 0.9;

  float2 rv2 = uv + t * 1.2;
  rv2.x *= 1.05;

  r = ROT;
  s = sin(r);
  c = cos(r);
  rot = float2x2(c, -s, s, c);
  rv2 = rot * rv2;
  rv2 *= ZOOM * 1.1;

  float star1 = moonTree_ShootingStar(rv1);
  float star2 = moonTree_ShootingStar(rv2);
  return clamp(star1 + star2, 0.0, 1.0);
}

// 获取地形高度
float moonTree_GetHeight(float x) {
  return sin(x * 0.412213) + sin(x) * 0.512347;
}

// 梯形盒子
float moonTree_TaperBox(float2 p, float wb, float wt, float yb, float yt,
                        float blur) {
  // 底部边缘
  float m = S(-blur, blur, p.y - yb);
  // 顶部边缘
  m *= S(blur, -blur, p.y - yt);
  // 镜像 x 获得两侧边缘
  p.x = abs(p.x);
  // 侧边缘
  float w = mix(wb, wt, (p.y - yb) / (yt - yb));
  m *= S(blur, -blur, p.x - w);
  return m;
}

// 绘制树
float4 moonTree_Tree(float2 uv, float3 col, float blur) {
  float m = moonTree_TaperBox(uv, 0.03, 0.03, -0.05, 0.25, blur); // 树干
  m += moonTree_TaperBox(uv, 0.2, 0.1, 0.25, 0.5, blur);          // 树冠 1
  m += moonTree_TaperBox(uv, 0.15, 0.05, 0.5, 0.75, blur);        // 树冠 2
  m += moonTree_TaperBox(uv, 0.1, 0.0, 0.75, 1.0, blur);          // 树尖

  blur *= 3.0;
  float shadow =
      moonTree_TaperBox(uv - float2(0.2, 0.0), 0.1, 0.5, 0.15, 0.253, blur);
  shadow +=
      moonTree_TaperBox(uv + float2(0.25, 0.0), 0.1, 0.5, 0.45, 0.503, blur);
  shadow +=
      moonTree_TaperBox(uv - float2(0.25, 0.0), 0.1, 0.5, 0.7, 0.753, blur);
  col -= shadow * 0.8;

  return float4(col, m);
}

// 绘制层
float4 moonTree_Layer(float2 uv, float blur) {
  float4 col = float4(0);
  float id = floor(uv.x);

  // 随机 [-1, 1]
  float n = moonTree_N11(id) * 2.0 - 1.0;
  float x = n * 0.3;
  float y = moonTree_GetHeight(uv.x);

  // 地面
  float ground = S(blur, -blur, uv.y - y);
  col += ground;

  y = moonTree_GetHeight(id + 0.5 - x);

  // 垂直网格
  uv.x = fract(uv.x) - 0.5;
  // 偏移 缩放树的大小 颜色
  float4 tree = moonTree_Tree((uv + float2(x, -y)) * float2(1, 1.0 + n * 0.2),
                              float3(1), blur);

  col = mix(col, tree, tree.a);
  col.a = max(ground, tree.a);
  return col;
}

// 月亮位置
float2 moonTree_MoonPos(float time) {
  float t = time * ORBIT_SPEED;
  return float2(sin(t), cos(t)) / 2.0;
}

// 月亮光晕
float4 moonTree_MoonGlow(float2 uv, float time) {
  float2 moonPos = moonTree_MoonPos(time);
  float md = length(uv - (moonPos - float2(0.07, 0.01)));
  float moon = S(0.1, -0.01, md - MOON_SIZE * 8.0);
  moon = mix(0.0, moon, clamp((moonPos.y + 0.2) * 3.0, 0.0, 1.0));

  float4 col = float4(moon);
  md = clamp(1.0 - md, 0.0, 1.0);
  md *= md;
  col.rgb *= md;
  return col;
}

// 片段着色器
fragment float4 moonTreeFragment(VertexOut in [[stage_in]],
                                 constant MoonTreeParams &params
                                 [[buffer(0)]]) {
  float2 fragCoord = in.uv * params.resolution;
  float2 uv = (fragCoord - 0.5 * params.resolution) / params.resolution.y;
  float2 M = (params.mouse / params.resolution) * 2.0 - 1.0;
  float t = params.time * SCROLL_SPEED;
  float blur = 0.005;

  // 星星闪烁 - Metal 中 dot 不能用于标量，改用直接乘法
  float twinkle =
      length(sin(uv + t)) * length(cos(uv * float2(22.0, 6.7) - t * 3.0));
  twinkle = sin(twinkle * 5.0) * 0.5 + 0.5;
  float stars = pow(moonTree_N21(uv * 1000.0), 1024.0) * twinkle;
  float4 col = float4(stars);

  // 月亮
  float2 moonPos = moonTree_MoonPos(params.time);
  float moon = S(0.01, -0.01, length(uv - moonPos) - MOON_SIZE);
  col *= 1.0 - moon;
  moon *=
      S(-0.01, 0.05, length(uv - (moonPos + float2(0.1, 0.05))) - MOON_SIZE);
  col += moon;

  // 流星
  col += moonTree_LayerShootingStars(uv, params.time);

  // 树木层
  float4 layer;
  for (float i = 0.0; i < 1.0; i += 1.0 / LAYER_COUNT) {
    float scale = mix(30.0, 1.0, i);
    blur = mix(0.05, 0.005, i);
    layer = moonTree_Layer(uv * scale + float2(t + i * 100.0, i) - M, blur);
    layer.rgb *= (1.0 - i) * TREE_COL;
    col = mix(col, layer, layer.a);
  }

  // 月亮光晕
  col += moonTree_MoonGlow(uv, params.time);

  // 前景层
  layer = moonTree_Layer(uv + float2(t, 1.0) - M, 0.07);
  col = mix(col, layer * 0.05, layer.a);

  return col;
}
