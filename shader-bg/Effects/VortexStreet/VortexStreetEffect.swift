//
//  VortexStreetEffect.swift
//  shader-bg
//
//  Created on 2025-11-01.
//
//  VisualEffect wrapper for the "Vortex Street" shader by dr2.
//

import Foundation
import MetalKit

final class VortexStreetEffect: VisualEffect {
  let name: String = "vortex_street"
  let displayName: String = "Vortex Street (dr2)"

  var preferredFramesPerSecond: Int { 15 }
  var occludedFramesPerSecond: Int { 4 }

  private var renderer: VortexStreetRenderer?
  private var startTime: CFTimeInterval?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = VortexStreetRenderer(device: device, size: size)
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

    renderer.draw(
      in: view,
      commandBuffer: commandBuffer,
      renderPassDescriptor: renderPassDescriptor)

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  func setUpdateRate(_ rate: Double) {
    // Vortex Street uses default frame rate handling.
  }
}
