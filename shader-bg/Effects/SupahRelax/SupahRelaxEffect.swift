//
//  SupahRelaxEffect.swift
//  shader-bg
//
//  Created on 2025-11-12.
//

import MetalKit

class SupahRelaxEffect: VisualEffect {
  var name: String { "supah_relax" }
  var displayName: String { "Supah Relax" }

  private var renderer: SupahRelaxRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = SupahRelaxRenderer(device: device, size: size)
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
