//
//  MoonTreeEffect.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//

import MetalKit

class MoonTreeEffect: VisualEffect {
  var name: String { "moon_tree" }
  var displayName: String { "Moon Tree" }

  private var renderer: MoonTreeRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = MoonTreeRenderer(device: device, size: size)
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
