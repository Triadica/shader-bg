//
//  ApollianTwistEffect.swift
//  shader-bg
//
//  Created on 2025-10-30.
//

import Foundation
import MetalKit

class ApollianTwistEffect: VisualEffect {
  var name: String = "apollian_twist"
  var displayName: String = "Apollian Twist"

  // 自定义帧率：由于动画速度已经很慢，使用 30fps 以节省性能
  var preferredFramesPerSecond: Int { 10 }
  var occludedFramesPerSecond: Int { 3 }  // 遮挡时进一步降低

  var renderer: ApollianTwistRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    let apollianTwistRenderer = ApollianTwistRenderer(device: device, size: size)
    self.renderer = apollianTwistRenderer
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func update(currentTime: CFTimeInterval) {
    // 时间更新在 draw 方法中处理
  }

  func draw(in view: MTKView) {
    // 应用帧率设置
    if view.preferredFramesPerSecond != preferredFramesPerSecond {
      view.preferredFramesPerSecond = preferredFramesPerSecond
    }

    guard let renderer = renderer,
      let commandBuffer = renderer.commandQueue.makeCommandBuffer(),
      let drawable = view.currentDrawable,
      let renderPassDescriptor = view.currentRenderPassDescriptor
    else {
      return
    }

    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear

    renderer.draw(
      in: view, commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  func setUpdateRate(_ rate: Double) {
    // Apollian Twist 使用自定义的帧率控制（30fps 可见，15fps 遮挡）
  }
}
