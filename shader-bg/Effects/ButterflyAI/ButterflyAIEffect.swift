//
//  ButterflyAIEffect.swift
//  shader-bg
//
//  Created on 2025-11-12.
//

import MetalKit

class ButterflyAIEffect: VisualEffect {
  var name: String { "butterfly_ai" }
  var displayName: String { "Butterfly AI" }

  private var renderer: ButterflyAIRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = ButterflyAIRenderer(device: device, size: size)
  }

  func update(currentTime: CFTimeInterval) {
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
