//
//  WaveformData.swift
//  shader-bg
//
//  Created on 2025-11-01.
//
//  Uniform parameters for the Waveform effect.
//

import simd

struct WaveformParams {
  var resolution: SIMD2<Float>
  var time: Float
  var padding: Float = 0
}
