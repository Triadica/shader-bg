//
//  WaveformEffect.swift
//  shader-bg
//
//  Created on 2025-11-01.
//
//  VisualEffect wrapper for the "Waveform" shader by XorDev.
//

import Foundation
import MetalKit

final class WaveformEffect: VisualEffect {
  let name: String = "waveform"
  let displayName: String = "Waveform (XorDev)"

  var preferredFramesPerSecond: Int { 18 }
  var occludedFramesPerSecond: Int { 4 }

  private var renderer: WaveformRenderer?
  private var startTime: CFTimeInterval?
  private var timeScale: Float = 1.0

  func setup(device: MTLDevice, size: CGSize) {
    renderer = WaveformRenderer(device: device, size: size)
    startTime = nil
    let baseRate = PerformanceManager.shared.highPerformanceRate
    let currentRate = PerformanceManager.shared.currentUpdateRate
    timeScale = baseRate > 0 ? Float(currentRate / baseRate) : 1.0
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
    renderer.update(time: elapsed * timeScale)
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
    let baseRate = PerformanceManager.shared.highPerformanceRate
    timeScale = baseRate > 0 ? Float(rate / baseRate) : 1.0
  }
}
