//
//  ParticlesInGravityRenderer.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Metal
import MetalKit
import simd

class ParticlesInGravityRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue

  var computePipelineState: MTLComputePipelineState?
  var renderPipelineState: MTLRenderPipelineState?

  var particleBuffer: MTLBuffer?
  var gravityParamsBuffer: MTLBuffer?

  var particles: [Particle] = []
  let particleCount = 3000  // 减少粒子数量以优化性能（从 5000 降低到 3000）

  var viewportSize: CGSize = .zero
  var lastUpdateTime: CFTimeInterval = 0
  var updateInterval: CFTimeInterval = 1.0 / 15.0  // 可变更新间隔，默认每秒更新 15 次

  init(device: MTLDevice, size: CGSize) {
    self.device = device
    self.viewportSize = size

    guard let queue = device.makeCommandQueue() else {
      fatalError("Failed to create command queue")
    }
    self.commandQueue = queue

    setupPipelines()
    setupParticles()
    setupBuffers()
  }

  func setupPipelines() {
    guard let library = device.makeDefaultLibrary() else {
      fatalError("Failed to create Metal library")
    }

    // 设置 Compute Pipeline
    if let computeFunction = library.makeFunction(name: "updateParticles") {
      do {
        computePipelineState = try device.makeComputePipelineState(function: computeFunction)
      } catch {
        fatalError("Failed to create compute pipeline state: \(error)")
      }
    }

    // 设置 Render Pipeline
    let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
    renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    // 启用混合以支持透明粒子
    renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
    renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
    renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
    renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
    renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

    do {
      renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    } catch {
      fatalError("Failed to create render pipeline state: \(error)")
    }
  }

  func setupParticles() {
    particles.removeAll()

    let centerX = Float(viewportSize.width / 2)
    let centerY = Float(viewportSize.height / 2)

    // 生成随机分布的粒子
    for _ in 0..<particleCount {
      // 随机位置（在屏幕范围内）
      let angle = Float.random(in: 0...(2 * .pi))
      let radius = Float.random(in: 100...500)
      let x = centerX + cos(angle) * radius
      let y = centerY + sin(angle) * radius

      // 随机初始速度
      let vx = Float.random(in: -20...20)
      let vy = Float.random(in: -20...20)

      // 随机质量
      let mass = Float.random(in: 0.5...2.0)

      // 随机颜色（蓝紫色调）
      let hue = Float.random(in: 0.55...0.75)  // 蓝色到紫色
      let color = hsbToRgb(h: hue, s: 0.7, b: 0.9, a: 0.8)

      let particle = Particle(
        position: SIMD2<Float>(x, y),
        velocity: SIMD2<Float>(vx, vy),
        mass: mass,
        color: color
      )

      particles.append(particle)
    }
  }

  func setupBuffers() {
    let particleDataSize = particles.count * MemoryLayout<Particle>.stride
    particleBuffer = device.makeBuffer(
      bytes: particles, length: particleDataSize, options: .storageModeShared)

    var gravityParams = GravityParams(
      centerPosition: SIMD2<Float>(Float(viewportSize.width / 2), Float(viewportSize.height / 2)),
      gravityStrength: 5000.0,
      deltaTime: Float(updateInterval),
      damping: 0.995
    )

    let gravityParamsSize = MemoryLayout<GravityParams>.stride
    gravityParamsBuffer = device.makeBuffer(
      bytes: &gravityParams, length: gravityParamsSize, options: .storageModeShared)
  }

  func updateViewportSize(_ size: CGSize) {
    viewportSize = size
    // 窗口大小改变时，不重新生成粒子，保持它们的当前状态
    // 只有引力中心会在每次物理更新时自动调整到新的窗口中心
  }

  func updateParticles(currentTime: CFTimeInterval) {
    // 限制更新频率为每秒 10 次
    if currentTime - lastUpdateTime < updateInterval {
      return
    }
    lastUpdateTime = currentTime

    guard let computePipeline = computePipelineState,
      let particleBuffer = particleBuffer,
      let gravityParamsBuffer = gravityParamsBuffer
    else {
      return
    }

    // 动态更新引力中心位置为当前窗口的正中心
    let gravityParams = GravityParams(
      centerPosition: SIMD2<Float>(Float(viewportSize.width / 2), Float(viewportSize.height / 2)),
      gravityStrength: 5000.0,
      deltaTime: Float(updateInterval),
      damping: 0.995
    )

    // 更新引力参数缓冲区
    let gravityParamsPointer = gravityParamsBuffer.contents().assumingMemoryBound(
      to: GravityParams.self)
    gravityParamsPointer.pointee = gravityParams

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()
    else {
      return
    }

    computeEncoder.setComputePipelineState(computePipeline)
    computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
    computeEncoder.setBuffer(gravityParamsBuffer, offset: 0, index: 1)

    let threadGroupSize = MTLSize(
      width: min(computePipeline.threadExecutionWidth, particleCount), height: 1, depth: 1)
    let threadGroups = MTLSize(
      width: (particleCount + threadGroupSize.width - 1) / threadGroupSize.width, height: 1,
      depth: 1)

    computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    computeEncoder.endEncoding()

    commandBuffer.commit()
  }

  func draw(in view: MTKView) {
    // 同步使用当前 drawable 的尺寸，避免在多显示器/缩放变化时出现中心偏移
    let currentDrawableSize = view.drawableSize
    if currentDrawableSize.width > 0 && currentDrawableSize.height > 0 {
      viewportSize = currentDrawableSize
    }

    let currentTime = CACurrentMediaTime()
    updateParticles(currentTime: currentTime)

    guard let drawable = view.currentDrawable,
      let renderPipeline = renderPipelineState,
      let particleBuffer = particleBuffer
    else {
      return
    }

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
      red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = .store

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    renderEncoder.setRenderPipelineState(renderPipeline)
    renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)

    var viewportSizeVector = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
    renderEncoder.setVertexBytes(
      &viewportSizeVector, length: MemoryLayout<SIMD2<Float>>.size, index: 1)

    renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)

    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  // HSB 转 RGB 辅助函数
  func hsbToRgb(h: Float, s: Float, b: Float, a: Float) -> SIMD4<Float> {
    let c = b * s
    let x = c * (1 - abs(fmod(h * 6, 2) - 1))
    let m = b - c

    var r: Float = 0
    var g: Float = 0
    var bl: Float = 0

    let hue = h * 6
    if hue < 1 {
      r = c
      g = x
      bl = 0
    } else if hue < 2 {
      r = x
      g = c
      bl = 0
    } else if hue < 3 {
      r = 0
      g = c
      bl = x
    } else if hue < 4 {
      r = 0
      g = x
      bl = c
    } else if hue < 5 {
      r = x
      g = 0
      bl = c
    } else {
      r = c
      g = 0
      bl = x
    }

    return SIMD4<Float>(r + m, g + m, bl + m, a)
  }
}
