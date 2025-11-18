//
//  CosmicFireworksEffect.swift
//  shader-bg
//
//  Created on 2025-11-05.
//

import MetalKit

class CosmicFireworksEffect: VisualEffect {
  var name: String = "cosmic_fireworks"
  var displayName: String = "Cosmic Fireworks"

  private var renderer: CosmicFireworksRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = CosmicFireworksRenderer(device: device, size: size)
    print("Cosmic Fireworks 效果已初始化")
  }

  func update(currentTime: TimeInterval) {
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
