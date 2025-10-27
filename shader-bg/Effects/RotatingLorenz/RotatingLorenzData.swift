//
//  RotatingLorenzData.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Foundation
import simd

// Lorenz 粒子数据结构
struct LorenzParticle {
  var position: SIMD3<Float>  // 3D 位置 (x, y, z)
  var color: SIMD4<Float>  // 颜色 (RGBA)
}

// Lorenz 系统参数
struct LorenzParams {
  var sigma: Float  // σ 参数，通常为 10
  var rho: Float  // ρ 参数，通常为 28
  var beta: Float  // β 参数，通常为 8/3
  var deltaTime: Float  // 时间步长
  var rotation: Float  // 旋转角度
  var scale: Float  // 缩放系数
}
