//
//  RainbowTwisterData.swift
//  shader-bg
//
//  Created on 2025-11-01.
//

import simd

struct RainbowTwisterParams {
  var resolution: SIMD2<Float>
  var time: Float
  var padding: Float

  init(resolution: SIMD2<Float>, time: Float) {
    self.resolution = resolution
    self.time = time
    self.padding = 0
  }
}
