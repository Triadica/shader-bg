//
//  ShootingStarsData.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//

import Foundation
import simd

struct ShootingStarsParams {
  var time: Float
  var resolution: SIMD2<Float>
  var padding: SIMD2<Float>  // 用于内存对齐
}
