//
//  SinMoveEffect.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/16.
//

import Foundation
import Metal
import MetalKit

class SinMoveEffect: VisualEffect {
  var name: String = "sin_move"
  var displayName: String = "Sin Move"
  var preferredFramesPerSecond: Int = 30
  var occludedFramesPerSecond: Int = 15

  private var renderer: SinMoveRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = SinMoveRenderer(device: device)
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
