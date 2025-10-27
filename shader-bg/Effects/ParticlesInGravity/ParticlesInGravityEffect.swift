//
//  ParticlesInGravityEffect.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import MetalKit
import simd

class ParticlesInGravityEffect: VisualEffect {
  var name: String = "particles_in_gravity"
  var displayName: String = "Particles in Gravity"

  private var renderer: ParticlesInGravityRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = ParticlesInGravityRenderer(device: device, size: size)
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
