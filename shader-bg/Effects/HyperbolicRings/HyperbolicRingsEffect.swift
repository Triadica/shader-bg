//
//  HyperbolicRingsEffect.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//

import MetalKit

class HyperbolicRingsEffect: VisualEffect {
  var name: String { "hyperbolic_rings" }
  var displayName: String { "Hyperbolic Rings" }

  private var renderer: HyperbolicRingsRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = HyperbolicRingsRenderer(device: device, size: size)
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
