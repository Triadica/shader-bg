//
//  SimplePlasmaEffect.swift
//  shader-bg
//
//  Created on 2025-11-03.
//

import MetalKit

class SimplePlasmaEffect: VisualEffect {
  var name: String { "simple_plasma" }
  var displayName: String { "Simple Plasma" }

  private var renderer: SimplePlasmaRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = SimplePlasmaRenderer(device: device, size: size)
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
