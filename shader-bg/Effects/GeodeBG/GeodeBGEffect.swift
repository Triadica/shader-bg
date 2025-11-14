//
//  GeodeBGEffect.swift
//  shader-bg
//
//  Created on 2025-11-12.
//

import MetalKit

class GeodeBGEffect: VisualEffect {
  var name: String { "geode_bg" }
  var displayName: String { "Geode BG" }

  private var renderer: GeodeBGRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = GeodeBGRenderer(device: device, size: size)
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
