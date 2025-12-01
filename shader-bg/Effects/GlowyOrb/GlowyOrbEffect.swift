//
//  GlowyOrbEffect.swift
//  shader-bg
//
//  Created on 2025-11-03.
//

import MetalKit
import simd

class GlowyOrbEffect: VisualEffect {
  var name: String = "glowy_orb"
  var displayName: String = "Glowy Orb"

  private var renderer: GlowyOrbRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = GlowyOrbRenderer(device: device, size: size)
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
