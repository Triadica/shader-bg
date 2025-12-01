//
//  ClockData.swift
//  shader-bg
//
//  Created on 2025-10-31.
//
//  Parameters passed to the IQ Clock shader adaptation.
//

import simd

struct ClockParams {
  var resolution: SIMD2<Float>
  var seconds: Float
  var minutes: Float
  var hours: Float
  var fractionalSecond: Float
  var padding: SIMD3<Float> = .zero
}
