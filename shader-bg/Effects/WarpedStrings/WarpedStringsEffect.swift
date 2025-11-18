//
//  WarpedStringsEffect.swift
//  shader-bg
//
//  Created on 2025-11-04.
//

import MetalKit

class WarpedStringsEffect: VisualEffect {
  var name: String { "warped_strings" }
  var displayName: String { "Warped Strings" }

  private var renderer: WarpedStringsRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = WarpedStringsRenderer(device: device, size: size)
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
