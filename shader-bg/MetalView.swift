//
//  MetalView.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
  func makeNSView(context: Context) -> MTKView {
    let mtkView = MTKView()
    mtkView.device = MTLCreateSystemDefaultDevice()
    mtkView.delegate = context.coordinator
    mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
    mtkView.preferredFramesPerSecond = 60
    mtkView.enableSetNeedsDisplay = false
    mtkView.isPaused = false

    // 启用混合以支持透明度
    mtkView.framebufferOnly = false

    return mtkView
  }

  func updateNSView(_ nsView: MTKView, context: Context) {
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, MTKViewDelegate {
    var parent: MetalView
    // 每个 MetalView 都有自己的效果实例，而不是共享
    private var currentEffect: VisualEffect?
    private var device: MTLDevice?
    private var isActive = true

    init(_ parent: MetalView) {
      self.parent = parent
      super.init()
    }

    deinit {
      isActive = false
      currentEffect = nil
      print("Coordinator 被释放")
    }

    func initializeEffect(device: MTLDevice, size: CGSize) {
      guard currentEffect == nil, size.width > 0, size.height > 0 else { return }

      self.device = device

      // 根据全局 EffectManager 的当前索引创建对应的效果
      let effectIndex = EffectManager.shared.currentEffectIndex
      switchToEffect(at: effectIndex, size: size)

      print("效果已初始化: \(currentEffect?.displayName ?? "unknown"), size: \(size)")
    }

    func switchToEffect(at index: Int, size: CGSize) {
      guard let device = self.device, size.width > 0, size.height > 0 else { return }

      let availableEffects = EffectManager.shared.availableEffects
      guard index < availableEffects.count else { return }

      let effectType = availableEffects[index]

      // 清理旧效果
      currentEffect = nil

      // 创建新的效果实例
      let newEffect: VisualEffect
      switch effectType.name {
      case "noise_halo":
        newEffect = NoiseHaloEffect()
      case "particles_in_gravity":
        newEffect = ParticlesInGravityEffect()
      case "rotating_lorenz":
        newEffect = RotatingLorenzEffect()
      case "liquid_tunnel":
        newEffect = LiquidTunnelEffect()
      default:
        newEffect = NoiseHaloEffect()
      }

      newEffect.setup(device: device, size: size)
      currentEffect = newEffect

      print("切换到效果: \(newEffect.displayName), size: \(size)")
    }

    func setUpdateRate(_ rate: Double) {
      currentEffect?.setUpdateRate(rate)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
      if currentEffect == nil, let device = view.device {
        initializeEffect(device: device, size: size)
      } else {
        currentEffect?.updateViewportSize(size)
      }
    }

    func draw(in view: MTKView) {
      guard isActive else { return }

      // 确保效果已初始化
      if currentEffect == nil, let device = view.device, view.drawableSize.width > 0 {
        initializeEffect(device: device, size: view.drawableSize)
      }

      guard currentEffect != nil else { return }

      let currentTime = CACurrentMediaTime()
      currentEffect?.update(currentTime: currentTime)
      currentEffect?.draw(in: view)
    }
  }
}
