//
//  SmokeRingRenderer.swift
//  shader-bg
//
//  Created on 2025-11-07.
//

import Metal
import MetalKit
import simd

class SmokeRingRenderer {
  let device: MTLDevice
  let commandQueue: MTLCommandQueue

  // Metal resources
  private var renderPipelineState: MTLRenderPipelineState!
  private var paramsBuffer: MTLBuffer!
  private var noiseTexture: MTLTexture!

  var viewportSize: CGSize = .zero
  private var time: Float = 0.0
  private var lastUpdateTime: CFTimeInterval = 0.0
  private var lastDrawTime: CFTimeInterval = 0.0
  var updateInterval: Double = 1.0 / 10.0  // 10 FPS（进一步降低帧率）

  init(device: MTLDevice, size: CGSize) {
    self.device = device
    self.viewportSize = size

    guard let queue = device.makeCommandQueue() else {
      fatalError("Failed to create command queue")
    }
    self.commandQueue = queue

    setupNoiseTexture()
    setupPipeline()
    setupBuffers()
  }

  deinit {
    // 清理 Metal 资源
    renderPipelineState = nil
    paramsBuffer = nil
    noiseTexture = nil
    print("SmokeRingRenderer 已释放")
  }

  private func setupNoiseTexture() {
    // 创建噪声纹理
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm,
      width: 256,
      height: 256,
      mipmapped: false
    )
    textureDescriptor.usage = [.shaderRead]

    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
      fatalError("Failed to create noise texture")
    }

    // 生成噪声数据
    var noiseData = [UInt8](repeating: 0, count: 256 * 256 * 4)
    for i in 0..<(256 * 256) {
      let r = UInt8.random(in: 0...255)
      let g = UInt8.random(in: 0...255)
      let b = UInt8.random(in: 0...255)
      noiseData[i * 4 + 0] = r
      noiseData[i * 4 + 1] = g
      noiseData[i * 4 + 2] = b
      noiseData[i * 4 + 3] = 255
    }

    let region = MTLRegionMake2D(0, 0, 256, 256)
    texture.replace(
      region: region, mipmapLevel: 0, withBytes: noiseData,
      bytesPerRow: 256 * 4)

    self.noiseTexture = texture
  }

  private func setupPipeline() {
    guard let library = device.makeDefaultLibrary() else {
      fatalError("Failed to create Metal library")
    }

    let vertexFunction = library.makeFunction(name: "smokeRingVertex")
    let fragmentFunction = library.makeFunction(name: "smokeRingFragment")

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    // 启用透明混合
    pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add

    do {
      renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
      fatalError("Failed to create render pipeline state: \(error)")
    }
  }

  private func setupBuffers() {
    // 创建参数缓冲区
    paramsBuffer = device.makeBuffer(
      length: MemoryLayout<SmokeRingParams>.stride,
      options: [.storageModeShared]
    )
  }

  func updateParticles(currentTime: CFTimeInterval) {
    // 限制更新频率
    if currentTime - lastUpdateTime < updateInterval {
      return
    }
    lastUpdateTime = currentTime

    // 更新时间（减慢到原始速度的 1/8，调整为 10fps）
    time += 0.0125  // 10fps * 0.0125 = 每秒增加约 0.125（原速度的 1/8）
  }

  func draw(in view: MTKView) {
    // 限制实际绘制频率
    let currentTime = CACurrentMediaTime()
    if currentTime - lastDrawTime < updateInterval {
      return
    }
    lastDrawTime = currentTime

    // 检查资源是否有效
    guard let renderPipeline = renderPipelineState,
      let paramsBuffer = paramsBuffer,
      let noiseTexture = noiseTexture
    else {
      return
    }

    // 获取 drawable，如果失败则直接返回
    guard let drawable = view.currentDrawable else {
      return
    }

    // 更新参数
    updateParams(viewportSize: view.drawableSize)

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
      red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = .store

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    renderEncoder.setRenderPipelineState(renderPipeline)
    renderEncoder.setFragmentBuffer(paramsBuffer, offset: 0, index: 0)
    renderEncoder.setFragmentTexture(noiseTexture, index: 0)

    // 绘制全屏三角形
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

    renderEncoder.endEncoding()

    // 再次检查 drawable 是否仍然有效（防止屏幕断开）
    if let finalDrawable = view.currentDrawable {
      commandBuffer.present(finalDrawable)
    }

    commandBuffer.commit()
  }

  private func updateParams(viewportSize: CGSize) {
    guard let paramsBuffer = paramsBuffer else { return }

    // 分辨率缩放到 30%（最大程度降低）
    let scale: Float = 0.3
    var params = SmokeRingParams(
      time: time,
      resolution: SIMD2<Float>(
        Float(viewportSize.width) * scale, Float(viewportSize.height) * scale),
      padding: 0
    )

    paramsBuffer.contents().copyMemory(
      from: &params, byteCount: MemoryLayout<SmokeRingParams>.stride)
  }
}
