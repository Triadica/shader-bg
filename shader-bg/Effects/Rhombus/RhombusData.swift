//
//  RhombusData.swift
//  shader-bg
//
//  Created on 2025-10-29.
//

import Foundation
import simd

// Rhombus 着色器的参数
struct RhombusParams {
  var resolution: SIMD2<Float>  // 屏幕分辨率
  var time: Float  // 时间
  var padding: Float  // 对齐到16字节
}
