//
//  ParticlesInGravityEffect.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import MetalKit
import simd

class ParticlesInGravityEffect: VisualEffect {
  var name: String = "particles_in_gravity"
  var displayName: String = "Particles in Gravity"

  // 使用默认帧率：可见 60fps，遮挡 30fps
  // var preferredFramesPerSecond: Int { 60 }
  // var occludedFramesPerSecond: Int { 30 }

  private var renderer: ParticlesInGravityRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = ParticlesInGravityRenderer(device: device, size: size)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  // 在首次真正获得外接屏的有效 drawableSize 或缩放变化时，
  // 需要以新中心重置粒子分布并重建相关缓冲区，避免初始中心偏移。
  func handleSignificantResize(to size: CGSize) {
    guard let renderer = renderer else { return }
    renderer.viewportSize = size
    renderer.setupParticles()
    renderer.setupBuffers()
  }

  func update(currentTime: CFTimeInterval) {
    renderer?.updateParticles(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    // 应用帧率设置
    if view.preferredFramesPerSecond != preferredFramesPerSecond {
      view.preferredFramesPerSecond = preferredFramesPerSecond
    }
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    renderer?.updateInterval = 1.0 / rate
  }
}
