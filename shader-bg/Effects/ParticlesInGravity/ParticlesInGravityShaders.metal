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
};

// 引力场参数
struct GravityParams {
  float2 centerPosition;
  float gravityStrength;
  float deltaTime;
  float damping;
};

// Compute Shader: 更新粒子位置和速度
kernel void updateParticles(device Particle *particles [[buffer(0)]],
                            constant GravityParams &params [[buffer(1)]],
                            uint id [[thread_position_in_grid]]) {
  Particle particle = particles[id];

  // 计算到引力中心的向量
  float2 toCenter = params.centerPosition - particle.position;
  float distance = length(toCenter);

  // 避免除以零和过强的力
  distance = max(distance, 50.0);

  // 计算引力加速度: F = G * m / r^2
  float2 direction = normalize(toCenter);
  float force = params.gravityStrength * particle.mass / (distance * distance);
  float2 acceleration = direction * force;

  // 更新速度（应用阻尼）
  particle.velocity += acceleration * params.deltaTime;
  particle.velocity *= params.damping;

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

  particles[id] = particle;
}

// Vertex Shader: 传递顶点数据
struct VertexOut {
  float4 position [[position]];
  float pointSize [[point_size]];
  float4 color;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              constant Particle *particles [[buffer(0)]],
                              constant float2 &viewportSize [[buffer(1)]]) {
  VertexOut out;

  Particle particle = particles[vertexID];

  // 将粒子位置从屏幕坐标转换到 NDC（Normalized Device Coordinates）
  // 屏幕坐标：原点在左上角，X向右，Y向下
  // NDC坐标：原点在中心，X向右(-1到1)，Y向上(-1到1)
  float2 pixelSpacePosition = particle.position;

  // 转换到NDC：先移动到中心，然后归一化到[-1, 1]
  float2 normalizedPosition;
  normalizedPosition.x =
      (pixelSpacePosition.x - viewportSize.x / 2.0) / (viewportSize.x / 2.0);
  normalizedPosition.y = -((pixelSpacePosition.y - viewportSize.y / 2.0) /
                           (viewportSize.y / 2.0)); // Y轴翻转

  out.position = float4(normalizedPosition, 0.0, 1.0);
  out.color = particle.color;

  // 粒子大小根据质量调整，同时考虑屏幕尺寸以保持一致的视觉效果
  // 使用较小维度作为基准，确保在不同纵横比屏幕上显示一致
  float minDimension = min(viewportSize.x, viewportSize.y);
  out.pointSize = particle.mass * 3.0 * (minDimension / 1000.0);

  return out;
}

// Fragment Shader: 渲染粒子（圆形，带光晕效果）
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               float2 pointCoord [[point_coord]]) {
  // 计算到粒子中心的距离
  float2 center = float2(0.5, 0.5);
  float distance = length(pointCoord - center);

  // 创建圆形粒子，带有柔和的边缘
  float alpha = 1.0 - smoothstep(0.3, 0.5, distance);

  // 中心更亮的光晕效果
  float glow = 1.0 - smoothstep(0.0, 0.5, distance);
  float3 color = in.color.rgb + glow * 0.3;

  return float4(color, alpha * in.color.a);
}
