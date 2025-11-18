//
//  MoonForestEffect.swift
//  shader-bg
//
//  Created on 2025-11-07.
//

import MetalKit

class MoonForestEffect: VisualEffect {
  var name: String = "MoonForest"
  var displayName: String = "Moon Forest"

  private var renderer: MoonForestRenderer?
  private var device: MTLDevice?

  init() {
    NSLog("[MoonForest] ✅ MoonForestEffect initialized")
  }

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[MoonForest] 🔧 Setup called with size: \(size)")
    self.device = device
    self.renderer = MoonForestRenderer(device: device, size: size)
    NSLog("[MoonForest] ✅ Renderer created")
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func update(currentTime: CFTimeInterval) {
    renderer?.updateParticles(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    if renderer == nil {
      NSLog("[MoonForest] ⚠️ Draw called but renderer is nil!")
    }
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    renderer?.updateInterval = rate
  }
}
