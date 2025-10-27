//
//  Particle.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Foundation
import simd

// 粒子数据结构，需要与 Metal Shader 中的结构匹配
struct Particle {
  var position: SIMD2<Float>  // 位置
  var velocity: SIMD2<Float>  // 速度
  var mass: Float  // 质量
  var color: SIMD4<Float>  // 颜色 (RGBA)
}

// 引力场参数
struct GravityParams {
  var centerPosition: SIMD2<Float>  // 引力中心位置
  var gravityStrength: Float  // 引力强度
  var deltaTime: Float  // 时间步长
  var damping: Float  // 阻尼系数
}
