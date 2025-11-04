//
//  RingRemixEffect.swift
//  shader-bg
//
//  Created on 2025-11-05.
//

import MetalKit

class RingRemixEffect: VisualEffect {
  var name: String = "ring_remix"
  var displayName: String = "Ring Remix"

  private var renderer: RingRemixRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = RingRemixRenderer(device: device, size: size)
    print("Ring Remix 效果已初始化")
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
