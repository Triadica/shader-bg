//
//  LiquidTunnelShaders.metal
//  shader-bg
//
//  Created by chen on 2025/10/28.
//
//  Forked from https://www.shadertoy.com/view/33cGDj
//  Based on "Clearly a bug" by various shader artists
//  Uses raymarching technique to render a fractal tunnel

#include <metal_stdlib>
using namespace metal;

struct LiquidTunnelParams {
  float time;
  float2 resolution;
  float padding1;
  float padding2;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

// 全屏三角形顶点着色器
vertex VertexOut liquidTunnelVertexShader(uint vertexID [[vertex_id]],
                                          constant LiquidTunnelParams &params
                                          [[buffer(0)]]) {
  VertexOut out;

  // 创建覆盖整个屏幕的三角形
  float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};

  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.texCoord = positions[vertexID] * 0.5 + 0.5;

  return out;
}

// 2D 旋转矩阵
float2x2 rot2D(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return float2x2(c, -s, s, c);
}

// Raymarching 主函数
fragment float4 liquidTunnelFragmentShader(VertexOut in [[stage_in]],
                                           constant LiquidTunnelParams &params
                                           [[buffer(0)]]) {
  // 将纹理坐标转换为屏幕坐标
  float2 C = in.texCoord * params.resolution;

  float i = 0.0; // 循环计数器
  float d = 0.0; // 到最近表面的距离

  // 添加噪声以减少条带效应
  float z = fract(dot(C, sin(C))) - 0.5;

  float4 o = float4(0.0); // 累积的颜色/光照
  float4 p;               // 沿光线的当前 3D 位置
  float4 O;               // 保存位置用于光照计算

  // Raymarching 循环 - 减少到 20 次迭代以优化性能
  // 牺牲一些细节以换取流畅体验
  for (float iter = 0.0; iter < 20.0; iter += 1.0) {
    i = iter;

    // 将 2D 像素转换为 3D 光线方向
    float2 r = params.resolution;
    float3 rayDir = normalize(float3(C - 0.5 * r, r.y));
    p = float4(z * rayDir, 0.1 * params.time);

    // 随时间在 3D 空间中移动
    p.z += params.time;

    // 保存位置用于光照计算
    O = p;

    // 应用旋转矩阵创建分形图案
    float2 pxy = p.xy;
    pxy = rot2D(2.0 + O.z) * pxy;

    // 这是原始代码中的一个 bug，但创造了有趣的图案
    // "happy little accident"
    pxy = rot2D(O.x + O.y) * pxy;
    p.xy = pxy;

    // 基于位置和空间扭曲计算颜色
    O = (1.0 + sin(0.5 * O.z + length(p.xyz - O.xyz) + float4(0, 4, 3, 6))) /
        (0.5 + 2.0 * dot(O.xy, O.xy));

    // 域重复 - 无限重复单条线和两个平面
    p = abs(fract(p) - 0.5);

    // 计算到最近表面的距离
    // 结合圆柱体和平面
    d = abs(min(length(p.xy) - 0.125, min(p.x, p.y) + 1e-3)) + 1e-3;

    // 添加光照贡献（越靠近表面越亮）
    o += O.w / d * O;

    // 向前步进 - 增加步长以更快穿越空间
    z += 1.2 * d;
  }

  // tanh() 将累积亮度压缩到 0-1 范围
  // 调整缩放因子以补偿更少的迭代次数
  return tanh(o / 5e3);
}
