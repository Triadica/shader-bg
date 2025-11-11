//
//  HazyMorningGolfEffect.swift
//  shader-bg
//
//  Created on 2025-11-12.
//

import MetalKit

class HazyMorningGolfEffect: VisualEffect {
  var name: String { "hazy_morning_golf" }
  var displayName: String { "Hazy Morning Golf" }

  private var renderer: HazyMorningGolfRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = HazyMorningGolfRenderer(device: device, size: size)
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
