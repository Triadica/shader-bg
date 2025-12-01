//
//  RotatingLorenzShaders.metal
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

#include <metal_stdlib>
using namespace metal;

// Lorenz 粒子数据结构
struct LorenzParticle {
  float3 position;
  float4 color;
  uint groupId;
  uint indexInGroup;
};

// Lorenz 系统参数
struct LorenzParams {
  float sigma;
  float rho;
  float beta;
  float deltaTime;
  float rotation;
  float scale;
  uint particlesPerGroup;
  uint padding;
};

// Compute Shader: 更新 Lorenz 吸引子粒子
kernel void updateLorenzParticles(device LorenzParticle *particles
                                  [[buffer(0)]],
                                  constant LorenzParams &params [[buffer(1)]],
                                  uint id [[thread_position_in_grid]]) {
  LorenzParticle particle = particles[id];

  // 如果是组内第一个粒子（头部），按照 Lorenz 方程移动
  if (particle.indexInGroup == 0) {
    float3 pos = particle.position;

    // Lorenz 吸引子微分方程:
    // dx/dt = σ(y - x)
    // dy/dt = x(ρ - z) - y
    // dz/dt = xy - βz
    float dx = params.sigma * (pos.y - pos.x);
    float dy = pos.x * (params.rho - pos.z) - pos.y;
    float dz = pos.x * pos.y - params.beta * pos.z;

    // 更新位置（欧拉方法）
    pos.x += dx * params.deltaTime;
    pos.y += dy * params.deltaTime;
    pos.z += dz * params.deltaTime;

    particle.position = pos;

    // 根据 z 坐标动态调整颜色（创建彩虹效果）
    float hue = (pos.z + 30.0) / 60.0;        // 映射 z 到 [0, 1]
    hue = fract(hue + params.rotation * 0.1); // 添加旋转影响

    // HSV 转 RGB（简化版）
    float h = hue * 6.0;
    float c = 0.8;
    float x = c * (1.0 - abs(fmod(h, 2.0) - 1.0));

    float3 rgb;
    if (h < 1.0) {
      rgb = float3(c, x, 0);
    } else if (h < 2.0) {
      rgb = float3(x, c, 0);
    } else if (h < 3.0) {
      rgb = float3(0, c, x);
    } else if (h < 4.0) {
      rgb = float3(0, x, c);
    } else if (h < 5.0) {
      rgb = float3(x, 0, c);
    } else {
      rgb = float3(c, 0, x);
    }

    particle.color = float4(rgb, 0.7);
  }
  // 如果是跟随粒子，移动到前一个粒子的位置
  else {
    // 计算前一个粒子的索引
    uint prevParticleId = id - 1;

    // 获取前一个粒子的位置和颜色
    LorenzParticle prevParticle = particles[prevParticleId];

    // 跟随前一个粒子，使用平滑插值
    float smoothFactor = 0.3; // 平滑因子，值越小跟随越平滑
    particle.position =
        mix(particle.position, prevParticle.position, smoothFactor);

    // 颜色逐渐淡化
    float fadeFactor =
        1.0 - (float(particle.indexInGroup) / float(params.particlesPerGroup));
    particle.color = prevParticle.color;
    particle.color.a = prevParticle.color.a * fadeFactor * 0.8;
  }

  particles[id] = particle;
}

// Vertex Shader 输出
struct VertexOut {
  float4 position [[position]];
  float4 color;
};

// 辅助函数：旋转和投影 3D 点
float4 transformPoint(float3 pos, constant LorenzParams &params,
                      constant float2 &viewportSize) {
  // Lorenz 吸引子的中心大约在 (0, 0, 27)
  // 先平移到原点，旋转后再平移回来
  float3 center = float3(0.0, 0.0, 27.0);
  pos = pos - center;

  // 绕 Y 轴旋转（在 XZ 平面上旋转）
  float angle = params.rotation;
  float cosA = cos(angle);
  float sinA = sin(angle);

  float x1 = pos.x * cosA - pos.z * sinA;
  float z1 = pos.x * sinA + pos.z * cosA;
  float y1 = pos.y;

  // 平移回中心
  float3 rotatedPos = float3(x1, y1, z1) + center;

  // 透视投影（简单的正交投影 + 透视缩放）
  float perspectiveFactor = 1.0 / (1.0 + rotatedPos.z * 0.01);
  float2 projected =
      float2(rotatedPos.x, rotatedPos.y) * perspectiveFactor * params.scale;

  // 转换到 NDC 坐标
  float2 normalizedPosition;
  normalizedPosition.x = projected.x / (viewportSize.x / 2.0);
  normalizedPosition.y = projected.y / (viewportSize.y / 2.0);

  return float4(normalizedPosition, 0.0, 1.0);
}

// Vertex Shader: 生成线段的三角形
// 每个线段（2个粒子之间）生成6个顶点（2个三角形组成矩形）
vertex VertexOut lorenzVertexShader(uint vertexID [[vertex_id]],
                                    constant LorenzParticle *particles
                                    [[buffer(0)]],
                                    constant LorenzParams &params [[buffer(1)]],
                                    constant float2 &viewportSize
                                    [[buffer(2)]]) {
  VertexOut out;

  // 每个线段需要6个顶点（2个三角形）
  // vertexID 的布局：
  // 线段索引 = vertexID / 6
  // 顶点在线段内的索引 = vertexID % 6
  uint segmentIndex = vertexID / 6;
  uint vertexInSegment = vertexID % 6;

  // 计算当前粒子和下一个粒子的索引
  uint particleIndex = segmentIndex;
  uint nextParticleIndex = segmentIndex + 1;

  // 如果是组内最后一个粒子，不绘制线段
  LorenzParticle particle = particles[particleIndex];
  if (particle.indexInGroup == params.particlesPerGroup - 1) {
    // 退化三角形（所有顶点在同一位置）
    out.position = float4(0, 0, 0, 1);
    out.color = float4(0, 0, 0, 0);
    return out;
  }

  LorenzParticle nextParticle = particles[nextParticleIndex];

  // 投影两个点到屏幕空间
  float4 p1_screen = transformPoint(particle.position, params, viewportSize);
  float4 p2_screen =
      transformPoint(nextParticle.position, params, viewportSize);

  // 计算线段方向（在屏幕空间）
  float2 dir = normalize(p2_screen.xy - p1_screen.xy);

  // 计算垂直于线段的方向（与摄像机方向垂直）
  float2 perpendicular = float2(-dir.y, dir.x);

  // 线宽（在 NDC 空间中）
  float lineWidth = 0.002; // 可以调整线宽

  // 根据顶点索引生成矩形的4个角
  // 顶点布局：
  // 0, 1, 2 = 第一个三角形
  // 3, 4, 5 = 第二个三角形
  // 形成矩形：
  // p1-width --- p1+width
  //    |            |
  // p2-width --- p2+width

  float2 offset;
  float4 basePos;
  float4 color;

  if (vertexInSegment == 0) {
    // p1 - perpendicular
    basePos = p1_screen;
    offset = -perpendicular * lineWidth;
    color = particle.color;
  } else if (vertexInSegment == 1 || vertexInSegment == 3) {
    // p1 + perpendicular
    basePos = p1_screen;
    offset = perpendicular * lineWidth;
    color = particle.color;
  } else if (vertexInSegment == 2 || vertexInSegment == 4) {
    // p2 - perpendicular
    basePos = p2_screen;
    offset = -perpendicular * lineWidth;
    color = nextParticle.color;
  } else { // vertexInSegment == 5
    // p2 + perpendicular
    basePos = p2_screen;
    offset = perpendicular * lineWidth;
    color = nextParticle.color;
  }

  out.position = float4(basePos.xy + offset, basePos.z, basePos.w);
  out.color = color;

  return out;
}

// Fragment Shader: 渲染实线
fragment float4 lorenzFragmentShader(VertexOut in [[stage_in]]) {
  return in.color;
}
