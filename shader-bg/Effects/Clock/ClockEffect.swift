//
//  ClockEffect.swift
//  shader-bg
//
//  Created on 2025-10-31.
//
//  Visual effect wrapper around the IQ Clock renderer.
//

import Foundation
import MetalKit

final class ClockEffect: VisualEffect {
  let name: String = "clock"
  let displayName: String = "Clock (IQ)"

  // Clock hands need smooth motion, keep full frame-rate when visible.
  var preferredFramesPerSecond: Int { 60 }
  var occludedFramesPerSecond: Int { 15 }

  private var renderer: ClockRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = ClockRenderer(device: device, size: size)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func handleSignificantResize(to size: CGSize) {
    renderer?.viewportSize = size
  }

  func update(currentTime: CFTimeInterval) {
    // Time is pulled directly in the renderer before each draw call.
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

    renderer.draw(
      in: view, commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  func setUpdateRate(_ rate: Double) {
    // Clock effect currently runs at the fixed preferred frame rate.
  }
}
