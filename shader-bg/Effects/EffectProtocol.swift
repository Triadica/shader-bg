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

  // 帧率配置：可见状态下的首选帧率（默认 60fps）
  var preferredFramesPerSecond: Int { get }

  // 帧率配置：被遮挡状态下的首选帧率（默认 30fps，节省资源）
  var occludedFramesPerSecond: Int { get }
  
  // 显示器索引（用于多显示器场景，可选实现）
  var screenIndex: Int { get set }

  func setup(device: MTLDevice, size: CGSize)
  func updateViewportSize(_ size: CGSize)
  // 当视口尺寸发生显著变化（例如首次窗口铺满屏幕或缩放切换）时调用，
  // 默认实现为仅更新视口，具体效果可重载以执行完整重置（如重新生成粒子并重建缓冲区）。
  func handleSignificantResize(to size: CGSize)
  func update(currentTime: CFTimeInterval)
  func draw(in view: MTKView)

  // 设置更新频率
  func setUpdateRate(_ rate: Double)
}

extension VisualEffect {
  func handleSignificantResize(to size: CGSize) {
    updateViewportSize(size)
  }

  // 默认帧率配置
  var preferredFramesPerSecond: Int { 60 }
  var occludedFramesPerSecond: Int { 30 }
  
  // 默认显示器索引（-1 表示不区分显示器）
  var screenIndex: Int {
    get { -1 }
    set { } // 默认不做任何事
  }
}
