//
//  LakeRipplesRenderer.swift
//  shader-bg
//
//  Created by chen on 2025/12/05.
//

import Metal
import MetalKit

class LakeRipplesRenderer {
  private var pipelineState: MTLComputePipelineState?
  private var commandQueue: MTLCommandQueue?

  private var time: Float = 0.0
  private var viewportSize: CGSize = .zero
  
  /// 当前渲染器所在的显示器索引
  var screenIndex: Int = -1
  
  private var inputData: ShaderInputData = ShaderInputData(
    from: InputState(
      hasMouseActivity: false,
      mousePosition: SIMD2<Float>(0.5, 0.5),
      keyPositions: [],
      rippleEvents: [],
      mouseTrail: [],
      screenIndex: -1
    ),
    currentTime: 0
  )

  init(device: MTLDevice) {
    NSLog("[LakeRipplesRenderer] 🔧 Initializing renderer")
    self.commandQueue = device.makeCommandQueue()

    guard let library = device.makeDefaultLibrary() else {
      NSLog("[LakeRipplesRenderer] ❌ Failed to create Metal library")
      print("Failed to create Metal library")
      return
    }
    NSLog("[LakeRipplesRenderer] ✅ Metal library created")

    guard let kernelFunction = library.makeFunction(name: "lakeRipplesCompute") else {
      NSLog("[LakeRipplesRenderer] ❌ Failed to find lakeRipplesCompute function")
      print("Failed to find lakeRipplesCompute function")
      return
    }
    NSLog("[LakeRipplesRenderer] ✅ Found kernel function: lakeRipplesCompute")

    do {
      pipelineState = try device.makeComputePipelineState(function: kernelFunction)
      NSLog("[LakeRipplesRenderer] ✅ Compute pipeline state created successfully")
    } catch {
      NSLog("[LakeRipplesRenderer] ❌ Failed to create compute pipeline state: \(error)")
      print("Failed to create compute pipeline state: \(error)")
    }
  }

  func updateViewportSize(_ size: CGSize) {
    NSLog("[LakeRipplesRenderer] 📐 Viewport size updated: \(size)")
    self.viewportSize = size
  }

  func updateInputState(currentTime: CFTimeInterval) {
    // 只获取当前显示器的输入状态
    let inputState = InputEventManager.shared.getInputState(forScreen: screenIndex)
    inputData = ShaderInputData(from: inputState, currentTime: currentTime)
    
    // 调试日志
    if inputData.rippleCount > 0 {
      NSLog("[LakeRipplesRenderer] 屏幕\(screenIndex) 涟漪数量: \(inputData.rippleCount)")
    }
  }

  private var drawCount: Int = 0

  func draw(in view: MTKView) {
    // 前几帧输出日志
    if drawCount < 3 {
      NSLog(
        "[LakeRipplesRenderer] 🎨 Draw call #\(drawCount) - viewportSize: \(viewportSize), time: \(time), rippleCount: \(inputData.rippleCount)"
      )
      drawCount += 1
    }

    guard let drawable = view.currentDrawable else {
      NSLog("[LakeRipplesRenderer] ❌ No drawable available")
      return
    }

    guard let pipelineState = pipelineState else {
      NSLog("[LakeRipplesRenderer] ❌ No pipeline state available")
      return
    }

    guard let commandQueue = commandQueue else {
      NSLog("[LakeRipplesRenderer] ❌ No command queue available")
      return
    }

    time += Float(1.0 / Double(view.preferredFramesPerSecond))

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let commandEncoder = commandBuffer.makeComputeCommandEncoder()
    else {
      return
    }

    commandEncoder.setComputePipelineState(pipelineState)
    commandEncoder.setTexture(drawable.texture, index: 0)

    var timeVar = time
    commandEncoder.setBytes(&timeVar, length: MemoryLayout<Float>.stride, index: 0)
    
    // 传递输入数据到 shader
    var inputDataCopy = inputData
    commandEncoder.setBytes(&inputDataCopy, length: MemoryLayout<ShaderInputData>.stride, index: 1)

    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
    let threadGroups = MTLSize(
      width: (Int(viewportSize.width) + threadGroupSize.width - 1) / threadGroupSize.width,
      height: (Int(viewportSize.height) + threadGroupSize.height - 1) / threadGroupSize.height,
      depth: 1
    )

    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    commandEncoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
