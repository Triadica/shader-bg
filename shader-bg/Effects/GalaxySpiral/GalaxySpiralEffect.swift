//
//  GalaxySpiralEffect.swift
//  shader-bg
//
//  Created on 2025-11-04.
//

import MetalKit

class GalaxySpiralEffect: VisualEffect {
  var name: String = "galaxy_spiral"
  var displayName: String = "Galaxy Spiral"

  private var renderer: GalaxySpiralRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = GalaxySpiralRenderer(device: device, size: size)
    print("Galaxy Spiral 效果已初始化")
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
