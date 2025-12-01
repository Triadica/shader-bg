//
//  ShootingStarsEffect.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//

import MetalKit

class ShootingStarsEffect: VisualEffect {
  var name: String { "shooting_stars" }
  var displayName: String { "Shooting Stars" }

  private var renderer: ShootingStarsRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = ShootingStarsRenderer(device: device, size: size)
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
