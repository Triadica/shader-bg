//
//  RainbowRoadEffect.swift
//  shader-bg
//
//  Created on 2025-11-07.
//

import MetalKit

class RainbowRoadEffect: VisualEffect {
  var name: String = "RainbowRoad"
  var displayName: String = "Rainbow Road"

  private var renderer: RainbowRoadRenderer?
  private var device: MTLDevice?

  init() {
    NSLog("[RainbowRoad] ✅ RainbowRoadEffect initialized")
  }

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[RainbowRoad] 🔧 Setup called with size: \(size)")
    self.device = device
    self.renderer = RainbowRoadRenderer(device: device, size: size)
    NSLog("[RainbowRoad] ✅ Renderer created")
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func update(currentTime: CFTimeInterval) {
    renderer?.updateParticles(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    if renderer == nil {
      NSLog("[RainbowRoad] ⚠️ Draw called but renderer is nil!")
    }
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    renderer?.updateInterval = rate
  }
}
