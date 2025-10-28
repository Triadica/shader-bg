//
//  LiquidTunnelData.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import simd

// Liquid Tunnel 着色器参数
struct LiquidTunnelParams {
  var time: Float  // 时间参数
  var resolution: SIMD2<Float>  // 屏幕分辨率
  var padding1: Float = 0  // 对齐填充
  var padding2: Float = 0  // 对齐填充
}
