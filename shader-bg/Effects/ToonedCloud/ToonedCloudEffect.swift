//
//  ToonedCloudEffect.swift
//  shader-bg
//
//  Created on 2025-11-03.
//

import MetalKit

class ToonedCloudEffect: VisualEffect {
  var name: String { "tooned_cloud" }
  var displayName: String { "Tooned Cloud" }

  private var renderer: ToonedCloudRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = ToonedCloudRenderer(device: device, size: size)
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
