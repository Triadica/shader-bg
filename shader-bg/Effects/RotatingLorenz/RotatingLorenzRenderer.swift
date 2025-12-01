//
//  RotatingLorenzRenderer.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Metal
import MetalKit
import simd

class RotatingLorenzRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue

  var computePipelineState: MTLComputePipelineState?
  var renderPipelineState: MTLRenderPipelineState?

  var particleBuffer: MTLBuffer?
  var lorenzParamsBuffer: MTLBuffer?

  var particles: [LorenzParticle] = []
  let particleCount = 32000  // 总粒子数（400组 × 80粒子/组）
  let particlesPerGroup = 80  // 每组粒子数量（20 × 4）
  var groupCount: Int { particleCount / particlesPerGroup }  // 组数 = 400

  var viewportSize: CGSize = .zero
  var lastUpdateTime: CFTimeInterval = 0
  var updateInterval: CFTimeInterval = 1.0 / 15.0  // 可变更新间隔，默认每秒更新 15 次

  var rotation: Float = 0.0

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
    if let computeFunction = library.makeFunction(name: "updateLorenzParticles") {
      do {
        computePipelineState = try device.makeComputePipelineState(function: computeFunction)
      } catch {
        fatalError("Failed to create compute pipeline state: \(error)")
      }
    }

    // 设置 Render Pipeline
    let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "lorenzVertexShader")
    renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "lorenzFragmentShader")
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    // 启用混合
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

    // 创建粒子组，每组 80 个粒子
    for groupId in 0..<groupCount {
      // 为每组的头部粒子在 Lorenz 吸引子附近随机初始化位置
      // 扩大随机范围，使起始点更分散
      let x = Float.random(in: -15...15)  // 扩大：-5...5 → -15...15
      let y = Float.random(in: -15...15)  // 扩大：-5...5 → -15...15
      let z = Float.random(in: 0...40)  // 扩大：0...10 → 0...40
      let startPosition = SIMD3<Float>(x, y, z)

      // 创建该组的所有粒子
      for indexInGroup in 0..<particlesPerGroup {
        let particle = LorenzParticle(
          position: startPosition,  // 初始时所有粒子在同一位置
          color: SIMD4<Float>(1, 1, 1, 0.7),
          groupId: UInt32(groupId),
          indexInGroup: UInt32(indexInGroup)
        )

        particles.append(particle)
      }
    }
  }

  func setupBuffers() {
    let particleDataSize = particles.count * MemoryLayout<LorenzParticle>.stride
    particleBuffer = device.makeBuffer(
      bytes: particles, length: particleDataSize, options: .storageModeShared)

    var lorenzParams = LorenzParams(
      sigma: 10.0,
      rho: 28.0,
      beta: 8.0 / 3.0,
      deltaTime: 0.00125,  // 再减半：0.0025 → 0.00125
      rotation: 0.0,
      scale: 30.0,  // 放大2倍：15.0 → 30.0
      particlesPerGroup: UInt32(particlesPerGroup),
      padding: 0
    )

    let lorenzParamsSize = MemoryLayout<LorenzParams>.stride
    lorenzParamsBuffer = device.makeBuffer(
      bytes: &lorenzParams, length: lorenzParamsSize, options: .storageModeShared)
  }

  func updateParticles(currentTime: CFTimeInterval) {
    // 限制更新频率
    if currentTime - lastUpdateTime < updateInterval {
      return
    }
    lastUpdateTime = currentTime

    guard let computePipeline = computePipelineState,
      let particleBuffer = particleBuffer,
      let lorenzParamsBuffer = lorenzParamsBuffer
    else {
      return
    }

    // 更新旋转角度（减慢旋转速度）
    rotation += 0.007  // 减慢：0.015 → 0.007

    // 更新 Lorenz 参数
    let lorenzParams = LorenzParams(
      sigma: 10.0,
      rho: 28.0,
      beta: 8.0 / 3.0,
      deltaTime: 0.00125,  // 再减半：0.0025 → 0.00125
      rotation: rotation,
      scale: 30.0,  // 放大2倍：15.0 → 30.0
      particlesPerGroup: UInt32(particlesPerGroup),
      padding: 0
    )

    let lorenzParamsPointer = lorenzParamsBuffer.contents().assumingMemoryBound(
      to: LorenzParams.self)
    lorenzParamsPointer.pointee = lorenzParams

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()
    else {
      return
    }

    computeEncoder.setComputePipelineState(computePipeline)
    computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
    computeEncoder.setBuffer(lorenzParamsBuffer, offset: 0, index: 1)

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
    // 使用当前 drawable 的尺寸，确保在不同分辨率/缩放下投影居中
    let currentDrawableSize = view.drawableSize
    if currentDrawableSize.width > 0 && currentDrawableSize.height > 0 {
      viewportSize = currentDrawableSize
    }

    guard let drawable = view.currentDrawable,
      let renderPipeline = renderPipelineState,
      let particleBuffer = particleBuffer,
      let lorenzParamsBuffer = lorenzParamsBuffer
    else {
      return
    }

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
      red: 0.0, green: 0.0, blue: 0.05, alpha: 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = .store

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    renderEncoder.setRenderPipelineState(renderPipeline)
    renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(lorenzParamsBuffer, offset: 0, index: 1)

    var viewportSizeVector = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
    renderEncoder.setVertexBytes(
      &viewportSizeVector, length: MemoryLayout<SIMD2<Float>>.size, index: 2)

    // 每组有 particlesPerGroup 个粒子，可以形成 (particlesPerGroup - 1) 个线段
    // 每个线段用 6 个顶点（2个三角形）来渲染
    let segmentsPerGroup = particlesPerGroup - 1
    let totalSegments = groupCount * segmentsPerGroup
    let vertexCount = totalSegments * 6

    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)

    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
