//
//  KorotkoeEffect.swift
//  shader-bg
//
//  Created on 2025-11-12.
//

import MetalKit

class KorotkoeEffect: VisualEffect {
  var name: String { "korotkoe" }
  var displayName: String { "Korotkoe" }

  private var renderer: KorotkoeRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = KorotkoeRenderer(device: device, size: size)
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
