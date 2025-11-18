//
//  RhombusEffect.swift
//  shader-bg
//
//  Created on 2025-10-29.
//

import Foundation
import MetalKit

class RhombusEffect: VisualEffect {
  var name: String = "rhombus"
  var displayName: String = "Rhombus Pattern"

  // 使用默认帧率：可见 60fps，遮挡 30fps
  // var preferredFramesPerSecond: Int { 60 }
  // var occludedFramesPerSecond: Int { 30 }

  var renderer: RhombusRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    let rhombusRenderer = RhombusRenderer(device: device, size: size)
    self.renderer = rhombusRenderer
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

    // 设置清屏颜色为白色
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
      red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    renderPassDescriptor.colorAttachments[0].loadAction = .clear

    renderer.draw(
      in: view, commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  func setUpdateRate(_ rate: Double) {
    // 可选：如果需要控制更新频率
  }
}
