//
//  StainedLightsEffect.swift
//  shader-bg
//
//  Created on 2025-11-03.
//

import MetalKit

class StainedLightsEffect: VisualEffect {
  var name: String { "stained_lights" }
  var displayName: String { "Stained Lights" }

  private var renderer: StainedLightsRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = StainedLightsRenderer(device: device, size: size)
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
