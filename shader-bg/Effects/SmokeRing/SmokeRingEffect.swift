//
//  SmokeRingEffect.swift
//  shader-bg
//
//  Created on 2025-11-07.
//

import Metal
import MetalKit

class SmokeRingEffect: VisualEffect {
  private var renderer: SmokeRingRenderer?

  var name: String { "smoke_ring" }
  var displayName: String { "Smoke Ring" }

  func setup(device: MTLDevice, size: CGSize) {
    renderer = SmokeRingRenderer(device: device, size: size)
    print("Smoke Ring 效果已初始化")
  }

  func update(currentTime: Double) {
    renderer?.updateParticles(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func setUpdateRate(_ rate: Double) {
    renderer?.updateInterval = 1.0 / rate
  }
}
