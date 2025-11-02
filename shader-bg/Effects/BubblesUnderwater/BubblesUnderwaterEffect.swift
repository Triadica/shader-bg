//
//  BubblesUnderwaterEffect.swift
//  shader-bg
//
//  Created on 2025-11-03.
//

import MetalKit
import simd

class BubblesUnderwaterEffect: VisualEffect {
  var name: String = "bubbles"
  var displayName: String = "Bubbles Underwater"

  private var renderer: BubblesUnderwaterRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = BubblesUnderwaterRenderer(device: device, size: size)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func update(currentTime: CFTimeInterval) {
    renderer?.updateParticles(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    renderer?.updateInterval = 1.0 / rate
  }
}
