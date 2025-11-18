//
//  MobiusKnotEffect.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/15.
//

import Foundation
import Metal
import MetalKit

class MobiusKnotEffect: VisualEffect {
  var name: String = "mobius_knot"
  var displayName: String = "Mobius Knot"
  var preferredFramesPerSecond: Int = 1  // 降低到 1/32: 20/8/4 ≈ 0.625, 取 1
  var occludedFramesPerSecond: Int = 1  // 降低到 1/32: 10/8/4 ≈ 0.3125, 取 1

  private var renderer: MobiusKnotRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = MobiusKnotRenderer(device: device)
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
