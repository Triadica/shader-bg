//
//  LakeRipplesEffect.swift
//  shader-bg
//
//  Created by chen on 2025/12/05.
//

import MetalKit

/// 湖面涟漪效果 - 响应鼠标和键盘事件产生涟漪
class LakeRipplesEffect: VisualEffect {
  var name: String = "lake_ripples"
  var displayName: String = "Lake Ripples (Interactive)"
  var preferredFramesPerSecond: Int = 20
  var occludedFramesPerSecond: Int = 10

  /// 当前效果所在的显示器索引
  var screenIndex: Int = -1

  private var renderer: LakeRipplesRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    NSLog(
      "[LakeRipplesEffect] 🎬 Setting up Lake Ripples effect with size: \(size), screen: \(screenIndex)"
    )
    renderer = LakeRipplesRenderer(device: device)
    renderer?.screenIndex = screenIndex
    renderer?.updateViewportSize(size)

    // 启动输入事件监听
    InputEventManager.shared.startListening()
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[LakeRipplesEffect] 📏 Updating viewport size to: \(size)")
    renderer?.updateViewportSize(size)
    InputEventManager.shared.updateScreenSize()
  }

  func handleSignificantResize(to size: CGSize) {
    NSLog("[LakeRipplesEffect] 🔄 Handling significant resize to: \(size)")
    updateViewportSize(size)
  }

  func update(currentTime: CFTimeInterval) {
    // 更新输入状态（只获取当前显示器的事件）
    renderer?.updateInputState(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    // 不需要实现
  }

  deinit {
    // 注意：不在这里停止监听，因为其他效果可能也需要
    // InputEventManager.shared.stopListening()
  }
}
