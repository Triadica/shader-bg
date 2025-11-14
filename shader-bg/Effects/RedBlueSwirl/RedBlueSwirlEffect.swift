//
//  RedBlueSwirlEffect.swift
//  shader-bg
//
//  Created on 2025-11-06.
//

import Metal
import MetalKit

class RedBlueSwirlEffect: VisualEffect {
  private var renderer: RedBlueSwirlRenderer?

  var name: String { "red_blue_swirl" }
  var displayName: String { "Red Blue Swirl" }

  func setup(device: MTLDevice, size: CGSize) {
    renderer = RedBlueSwirlRenderer(device: device, size: size)
    print("Red Blue Swirl 效果已初始化")
  }

  func update(currentTime: Double) {
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
