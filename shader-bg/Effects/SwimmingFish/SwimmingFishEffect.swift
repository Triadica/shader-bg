//
//  SwimmingFishEffect.swift
//  shader-bg
//
//  Created by chen on 2025/12/06.
//

import MetalKit

/// 游动的小鱼效果 - 响应鼠标位置和点击
class SwimmingFishEffect: VisualEffect {
  var name: String = "swimming_fish"
  var displayName: String = "Swimming Fish (Interactive)"
  var preferredFramesPerSecond: Int = 12
  var occludedFramesPerSecond: Int = 4

  var screenIndex: Int = -1

  private var renderer: SwimmingFishRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    NSLog("[SwimmingFishEffect] Setting up with size: \(size), screen: \(screenIndex)")
    renderer = SwimmingFishRenderer(device: device)
    renderer?.screenIndex = screenIndex
    renderer?.updateViewportSize(size)

    InputEventManager.shared.startListening()
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    updateViewportSize(size)
  }

  func update(currentTime: CFTimeInterval) {
    renderer?.update(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {}
}
