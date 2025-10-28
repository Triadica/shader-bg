//
//  LiquidTunnelEffect.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import MetalKit
import simd

class LiquidTunnelEffect: VisualEffect {
  var name: String = "liquid_tunnel"
  var displayName: String = "Liquid Tunnel"

  private var renderer: LiquidTunnelRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = LiquidTunnelRenderer(device: device, size: size)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
    renderer?.setupBuffer()
  }

  func update(currentTime: CFTimeInterval) {
    // Renderer 会在 draw 中更新
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    renderer?.updateInterval = 1.0 / rate
  }
}
