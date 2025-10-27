//
//  EffectProtocol.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import MetalKit
import simd

// 效果协议，所有视觉效果都需要实现这个协议
protocol VisualEffect {
  var name: String { get }
  var displayName: String { get }

  func setup(device: MTLDevice, size: CGSize)
  func updateViewportSize(_ size: CGSize)
  func update(currentTime: CFTimeInterval)
  func draw(in view: MTKView)

  // 设置更新频率
  func setUpdateRate(_ rate: Double)
}
