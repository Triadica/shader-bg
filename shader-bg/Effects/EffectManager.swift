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
      RhombusEffect(),
      ApollianTwistEffect(),
      ClockEffect(),
      WaveformEffect(),
      VortexStreetEffect(),
      RainbowTwisterEffect(),
    ]

    // 检查环境变量 SHADER_BG_EFFECT 来决定默认效果
    // 可选值: "noise", "liquid", "gravity", "lorenz", "rhombus", "apollian", "clock", "waveform", "vortex"
    var defaultIndex = 3  // 默认为 Rotating Lorenz

    if let effectEnv = ProcessInfo.processInfo.environment["SHADER_BG_EFFECT"] {
      switch effectEnv.lowercased() {
      case "noise":
        defaultIndex = 0
      case "liquid":
        defaultIndex = 1
      case "gravity":
        defaultIndex = 2
      case "lorenz":
        defaultIndex = 3
      case "rhombus":
        defaultIndex = 4
      case "apollian":
        defaultIndex = 5
      case "clock":
        defaultIndex = 6
      case "waveform":
        defaultIndex = 7
      case "vortex":
        defaultIndex = 8
      case "rainbow":
        defaultIndex = 9
      default:
        print("Unknown SHADER_BG_EFFECT value: \(effectEnv), using default (lorenz)")
      }
    }

    // 设置默认效果
    if !availableEffects.isEmpty {
      let safeIndex = min(max(defaultIndex, 0), availableEffects.count - 1)
      currentEffect = availableEffects[safeIndex]
      currentEffectIndex = safeIndex
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
