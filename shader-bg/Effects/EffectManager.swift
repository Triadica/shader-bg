//
//  EffectManager.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Foundation
import MetalKit

// 效果管理器，负责管理和切换不同的视觉效果
class EffectManager {
  static let shared = EffectManager()

  private(set) var availableEffects: [VisualEffect] = []
  private(set) var currentEffect: VisualEffect?
  var currentEffectIndex: Int = 0  // 改为可写，用于多窗口同步

  var onEffectChanged: (() -> Void)?

  private init() {
    // 注册所有可用的效果
    registerEffects()
  }

  private func registerEffects() {
    availableEffects = [
      NoiseHaloEffect(),
      LiquidTunnelEffect(),
      ParticlesInGravityEffect(),
      RotatingLorenzEffect(),
    ]

    // 默认选择第一个效果（Noise Halo）
    if !availableEffects.isEmpty {
      currentEffect = availableEffects[0]
      currentEffectIndex = 0
    }
  }

  func switchToEffect(at index: Int, device: MTLDevice, size: CGSize) {
    guard index >= 0 && index < availableEffects.count else { return }

    currentEffectIndex = index
    currentEffect = availableEffects[index]
    currentEffect?.setup(device: device, size: size)

    onEffectChanged?()
  }

  func switchToEffect(named name: String, device: MTLDevice, size: CGSize) {
    if let index = availableEffects.firstIndex(where: { $0.name == name }) {
      switchToEffect(at: index, device: device, size: size)
    }
  }
}
