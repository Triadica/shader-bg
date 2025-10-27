//
//  RotatingLorenzEffect.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import MetalKit
import simd

class RotatingLorenzEffect: VisualEffect {
  var name: String = "rotating_lorenz"
  var displayName: String = "Rotating Lorenz"

  private var renderer: RotatingLorenzRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = RotatingLorenzRenderer(device: device, size: size)
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
