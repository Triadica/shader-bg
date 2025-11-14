//
//  GoldenJuliaData.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//

import Foundation
import simd

struct GoldenJuliaParams {
  var time: Float
  var resolution: SIMD2<Float>
  var mouse: SIMD2<Float>
  var mousePressed: Float
  var padding: Float  // 用于内存对齐
}
