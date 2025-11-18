//
//  Shaders.metal
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

#include <metal_stdlib>
using namespace metal;

// 粒子数据结构
struct Particle {
  float2 position;
  float2 velocity;
  float mass;
  float4 color;
  uint groupId;
  uint indexInGroup;
};

// 引力场参数
struct GravityParams {
  float2 centerPosition;
  float gravityStrength;
  float deltaTime;
  float damping;
  uint particlesPerGroup;
  uint padding;
};

// Compute Shader: 更新粒子位置和速度
kernel void updateParticles(device Particle *particles [[buffer(0)]],
                            constant GravityParams &params [[buffer(1)]],
                            uint id [[thread_position_in_grid]]) {
  Particle particle = particles[id];

  // 如果是组内第一个粒子（头部），按照物理运动
  if (particle.indexInGroup == 0) {
    // 计算到引力中心的向量
    float2 toCenter = params.centerPosition - particle.position;
    float distance = length(toCenter);

    // 避免除以零和过强的力
    distance = max(distance, 50.0);

    // 计算引力加速度: F = G * m / r^2
    float2 direction = normalize(toCenter);
    float force =
        params.gravityStrength * particle.mass / (distance * distance);
    float2 acceleration = direction * force;

    // 更新速度（移除阻尼，保持能量守恒）
    particle.velocity += acceleration * params.deltaTime;
    // particle.velocity *= params.damping;  // 移除阻尼

    // 更新位置
    particle.position += particle.velocity * params.deltaTime;

    // 边界处理：防止粒子飞出屏幕太远
    float maxDistance = 2000.0;
    if (length(particle.position - params.centerPosition) > maxDistance) {
      // 将粒子拉回到合理范围
      particle.position = params.centerPosition +
                          normalize(particle.position - params.centerPosition) *
                              maxDistance * 0.9;
      particle.velocity *= 0.5;
    }
  }
  // 如果是跟随粒子，直接继承前一个粒子的历史状态
  else {
    // 计算前一个粒子的索引
    uint prevParticleId = id - 1;

    // 获取前一个粒子的位置和速度
    Particle prevParticle = particles[prevParticleId];

    // 直接复制前一个粒子的位置和速度，形成轨迹
    // 不使用插值，保持轨迹长度恒定
    particle.position = prevParticle.position;
    particle.velocity = prevParticle.velocity;

    // 颜色逐渐淡化
    float fadeFactor =
        1.0 - (float(particle.indexInGroup) / float(params.particlesPerGroup));
    particle.color = prevParticle.color;
    particle.color.a = prevParticle.color.a * fadeFactor * 0.85;
  }

  particles[id] = particle;
}

// Vertex Shader: 传递顶点数据
struct VertexOut {
  float4 position [[position]];
  float4 color;
};

// 辅助函数：将屏幕坐标转换为 NDC
float2 screenToNDC(float2 screenPos, float2 viewportSize) {
  float2 normalizedPosition;
  normalizedPosition.x =
      (screenPos.x - viewportSize.x / 2.0) / (viewportSize.x / 2.0);
  normalizedPosition.y = -((screenPos.y - viewportSize.y / 2.0) /
                           (viewportSize.y / 2.0)); // Y轴翻转
  return normalizedPosition;
}

// Vertex Shader: 生成线段的三角形
// 每个线段（2个粒子之间）生成6个顶点（2个三角形组成矩形）
vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              constant Particle *particles [[buffer(0)]],
                              constant float2 &viewportSize [[buffer(1)]],
                              constant GravityParams &params [[buffer(2)]]) {
  VertexOut out;

  // 每个线段需要6个顶点（2个三角形）
  uint segmentIndex = vertexID / 6;
  uint vertexInSegment = vertexID % 6;

  // 计算当前粒子和下一个粒子的索引
  uint particleIndex = segmentIndex;
  uint nextParticleIndex = segmentIndex + 1;

  // 如果是组内最后一个粒子，不绘制线段
  Particle particle = particles[particleIndex];
  if (particle.indexInGroup == params.particlesPerGroup - 1) {
    // 退化三角形
    out.position = float4(0, 0, 0, 1);
    out.color = float4(0, 0, 0, 0);
    return out;
  }

  Particle nextParticle = particles[nextParticleIndex];

  // 转换到 NDC 坐标
  float2 p1_ndc = screenToNDC(particle.position, viewportSize);
  float2 p2_ndc = screenToNDC(nextParticle.position, viewportSize);

  // 计算线段方向
  float2 dir = normalize(p2_ndc - p1_ndc);

  // 计算垂直方向
  float2 perpendicular = float2(-dir.y, dir.x);

  // 线宽（在 NDC 空间中，根据质量调整）减少到原来的 1/4
  float lineWidth = 0.00075 * particle.mass; // 0.003 → 0.00075

  // 生成矩形的顶点
  float2 offset;
  float2 basePos;
  float4 color;

  if (vertexInSegment == 0) {
    basePos = p1_ndc;
    offset = -perpendicular * lineWidth;
    color = particle.color;
  } else if (vertexInSegment == 1 || vertexInSegment == 3) {
    basePos = p1_ndc;
    offset = perpendicular * lineWidth;
    color = particle.color;
  } else if (vertexInSegment == 2 || vertexInSegment == 4) {
    basePos = p2_ndc;
    offset = -perpendicular * lineWidth;
    color = nextParticle.color;
  } else { // vertexInSegment == 5
    basePos = p2_ndc;
    offset = perpendicular * lineWidth;
    color = nextParticle.color;
  }

  out.position = float4(basePos + offset, 0.0, 1.0);
  out.color = color;

  return out;
}

// Fragment Shader: 渲染实线轨迹
fragment float4 fragmentShader(VertexOut in [[stage_in]]) { return in.color; }
