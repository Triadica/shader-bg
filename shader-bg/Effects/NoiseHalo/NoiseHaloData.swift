//
//  NoiseHaloData.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import simd

// Noise Halo 着色器参数
struct NoiseHaloParams {
  var time: Float  // 时间参数
  var resolution: SIMD2<Float>  // 屏幕分辨率
  var padding1: Float = 0  // 对齐填充
  var padding2: Float = 0  // 对齐填充
}
