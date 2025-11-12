//
//  PetalSphereEffect.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//

import MetalKit

class PetalSphereEffect: VisualEffect {
  var name: String { "petal_sphere" }
  var displayName: String { "Petal Sphere" }

  private var renderer: PetalSphereRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = PetalSphereRenderer(device: device, size: size)
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
