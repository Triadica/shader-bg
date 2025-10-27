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
  let particleCount = 2000  // 减少粒子数量以优化性能（从 3000 降低到 2000）

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

    // 在 Lorenz 吸引子附近随机初始化粒子
    for _ in 0..<particleCount {
      let x = Float.random(in: -5...5)
      let y = Float.random(in: -5...5)
      let z = Float.random(in: 0...10)

      let particle = LorenzParticle(
        position: SIMD3<Float>(x, y, z),
        color: SIMD4<Float>(1, 1, 1, 0.7)
      )

      particles.append(particle)
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
      deltaTime: 0.005,
      rotation: 0.0,
      scale: 15.0  // 增大缩放比例，使效果更明显
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

    // 更新旋转角度（稍微加快旋转速度）
    rotation += 0.015

    // 更新 Lorenz 参数
    var lorenzParams = LorenzParams(
      sigma: 10.0,
      rho: 28.0,
      beta: 8.0 / 3.0,
      deltaTime: 0.005,
      rotation: rotation,
      scale: 15.0  // 增大缩放比例，使效果更明显
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

    renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)

    renderEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
