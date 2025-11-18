//
//  NewtonCloudEffect.swift
//  shader-bg
//
//  Created on 2025-11-08.
//

import MetalKit

class NewtonCloudEffect: VisualEffect {
  var name: String = "NewtonCloud"
  var displayName: String = "Newton Cloud"

  private var renderer: NewtonCloudRenderer?
  private var device: MTLDevice?

  init() {
    NSLog("[NewtonCloud] ✅ NewtonCloudEffect initialized")
  }

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[NewtonCloud] 🔧 Setup called with size: \(size)")
    self.device = device
    self.renderer = NewtonCloudRenderer(device: device, size: size)
    NSLog("[NewtonCloud] ✅ Renderer created")
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func update(currentTime: CFTimeInterval) {
    renderer?.updateParticles(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    if renderer == nil {
      NSLog("[NewtonCloud] ⚠️ Draw called but renderer is nil!")
    }
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    renderer?.updateInterval = rate
  }
}
