//
//  PixellatedRainEffect.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/15.
//

import Foundation
import Metal
import MetalKit

class PixellatedRainEffect: VisualEffect {
  var name: String = "pixellated_rain"
  var displayName: String = "Pixellated Rain"
  var preferredFramesPerSecond: Int = 30
  var occludedFramesPerSecond: Int = 15

  private var renderer: PixellatedRainRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = PixellatedRainRenderer(device: device)
    renderer?.updateViewportSize(size)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    updateViewportSize(size)
  }

  func update(currentTime: Double) {
    // Time is handled in shader
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    // Optional: adjust frame rate based on update rate
  }
}
