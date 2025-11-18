//
//  MobiusFlowEffect.swift
//  shader-bg
//
//  Created on 2025-11-02.
//

import Foundation
import MetalKit

final class MobiusFlowEffect: VisualEffect {
  let name: String = "mobius_flow"
  let displayName: String = "Mobius Flow"

  var preferredFramesPerSecond: Int { 20 }
  var occludedFramesPerSecond: Int { 5 }

  private var renderer: MobiusFlowRenderer?
  private var startTime: CFTimeInterval?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = MobiusFlowRenderer(device: device, size: size)
    startTime = nil
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func handleSignificantResize(to size: CGSize) {
    renderer?.viewportSize = size
  }

  func update(currentTime: CFTimeInterval) {
    guard let renderer else { return }

    if startTime == nil {
      startTime = currentTime
    }

    let elapsed = Float(currentTime - (startTime ?? currentTime))
    renderer.update(time: elapsed)
  }

  func draw(in view: MTKView) {
    guard
      let renderer,
      let commandBuffer = renderer.commandQueue.makeCommandBuffer(),
      let drawable = view.currentDrawable,
      let renderPassDescriptor = view.currentRenderPassDescriptor
    else {
      return
    }

    if view.preferredFramesPerSecond != preferredFramesPerSecond {
      view.preferredFramesPerSecond = preferredFramesPerSecond
    }

    renderer.viewportSize = view.drawableSize

    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

    renderer.render(
      commandBuffer: commandBuffer,
      renderPassDescriptor: renderPassDescriptor
    )

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  func setUpdateRate(_ rate: Double) {
    // Performance update rate is handled by the effect manager
  }
}
