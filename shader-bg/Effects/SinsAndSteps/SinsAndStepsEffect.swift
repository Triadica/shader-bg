//
//  SinsAndStepsEffect.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/13.
//

import MetalKit

class SinsAndStepsEffect: VisualEffect {
  var name: String { "sins_and_steps" }
  var displayName: String { "Sins and Steps" }

  private var renderer: SinsAndStepsRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = SinsAndStepsRenderer(device: device, size: size)
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
