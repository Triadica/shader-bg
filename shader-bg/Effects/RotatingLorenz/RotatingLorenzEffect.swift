//
//  RotatingLorenzEffect.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import MetalKit
import simd

class RotatingLorenzEffect: VisualEffect {
  var name: String = "rotating_lorenz"
  var displayName: String = "Rotating Lorenz"

  // 使用默认帧率：可见 60fps，遮挡 30fps
  // var preferredFramesPerSecond: Int { 60 }
  // var occludedFramesPerSecond: Int { 30 }

  private var renderer: RotatingLorenzRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = RotatingLorenzRenderer(device: device, size: size)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func update(currentTime: CFTimeInterval) {
    renderer?.updateParticles(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    // 应用帧率设置
    if view.preferredFramesPerSecond != preferredFramesPerSecond {
      view.preferredFramesPerSecond = preferredFramesPerSecond
    }
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    renderer?.updateInterval = 1.0 / rate
  }
}
