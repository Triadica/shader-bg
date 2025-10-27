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
};

// Lorenz 系统参数
struct LorenzParams {
  float sigma;
  float rho;
  float beta;
  float deltaTime;
  float rotation;
  float scale;
};

// Compute Shader: 更新 Lorenz 吸引子粒子
kernel void updateLorenzParticles(device LorenzParticle *particles
                                  [[buffer(0)]],
                                  constant LorenzParams &params [[buffer(1)]],
                                  uint id [[thread_position_in_grid]]) {
  LorenzParticle particle = particles[id];

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

  particles[id] = particle;
}

// Vertex Shader 输出
struct VertexOut {
  float4 position [[position]];
  float pointSize [[point_size]];
  float4 color;
};

// Vertex Shader: 3D 到 2D 投影并旋转
vertex VertexOut lorenzVertexShader(uint vertexID [[vertex_id]],
                                    constant LorenzParticle *particles
                                    [[buffer(0)]],
                                    constant LorenzParams &params [[buffer(1)]],
                                    constant float2 &viewportSize
                                    [[buffer(2)]]) {
  VertexOut out;

  LorenzParticle particle = particles[vertexID];
  float3 pos = particle.position;

  // 旋转矩阵（绕 Y 轴和 X 轴旋转）
  float angleY = params.rotation;
  float angleX = params.rotation * 0.5;

  // 绕 Y 轴旋转
  float cosY = cos(angleY);
  float sinY = sin(angleY);
  float x1 = pos.x * cosY - pos.z * sinY;
  float z1 = pos.x * sinY + pos.z * cosY;

  // 绕 X 轴旋转
  float cosX = cos(angleX);
  float sinX = sin(angleX);
  float y1 = pos.y * cosX - z1 * sinX;
  float z2 = pos.y * sinX + z1 * cosX;

  // 透视投影（简单的正交投影 + 透视缩放）
  float perspectiveFactor = 1.0 / (1.0 + z2 * 0.01);
  float2 projected = float2(x1, y1) * perspectiveFactor * params.scale;

  // 转换到 NDC 坐标
  float2 normalizedPosition;
  normalizedPosition.x = projected.x / (viewportSize.x / 2.0);
  normalizedPosition.y = projected.y / (viewportSize.y / 2.0);

  out.position = float4(normalizedPosition, 0.0, 1.0);
  out.color = particle.color;

  // 粒子大小随深度变化，同时根据屏幕尺寸调整
  float minDimension = min(viewportSize.x, viewportSize.y);
  out.pointSize = 3.0 * perspectiveFactor * (minDimension / 1000.0);

  return out;
}

// Fragment Shader: 渲染圆形粒子
fragment float4 lorenzFragmentShader(VertexOut in [[stage_in]],
                                     float2 pointCoord [[point_coord]]) {
  float2 center = float2(0.5, 0.5);
  float distance = length(pointCoord - center);

  // 圆形粒子
  float alpha = 1.0 - smoothstep(0.3, 0.5, distance);

  // 光晕效果
  float glow = 1.0 - smoothstep(0.0, 0.5, distance);
  float3 color = in.color.rgb + glow * 0.2;

  return float4(color, alpha * in.color.a);
}
