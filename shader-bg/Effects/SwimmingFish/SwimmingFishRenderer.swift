//
//  SwimmingFishRenderer.swift
//  shader-bg
//
//  Created by chen on 2025/12/06.
//

import Metal
import MetalKit
import simd

/// 小鱼数据结构 - 与 shader 保持一致
struct Fish {
  var position: SIMD2<Float>  // 位置
  var velocity: SIMD2<Float>  // 速度
  var targetVelocity: SIMD2<Float>  // 目标速度
  var size: Float  // 大小
  var phase: Float  // 摆尾相位
}

/// Shader 输入数据
struct FishShaderData {
  var fishCount: Int32
  var mousePosition: SIMD2<Float>
  var hasMouseActivity: Int32
  var isScared: Int32  // 是否被惊吓
  var time: Float
  var padding: Float = 0
}

class SwimmingFishRenderer {
  private var pipelineState: MTLComputePipelineState?
  private var commandQueue: MTLCommandQueue?
  private var viewportSize: CGSize = .zero

  var screenIndex: Int = -1

  // 小鱼群
  private var fishes: [Fish] = []
  private let fishCount = 20

  // 鱼数据 buffer
  private var fishBuffer: MTLBuffer?

  // 状态
  private var time: Float = 0
  private var isScared: Bool = false
  private var scareTime: CFTimeInterval = 0
  private let scareDuration: CFTimeInterval = 2.0

  // 上一次的鼠标位置（用于检测点击）
  private var lastRippleCount: Int = 0

  init(device: MTLDevice) {
    self.commandQueue = device.makeCommandQueue()

    guard let library = device.makeDefaultLibrary(),
      let kernelFunction = library.makeFunction(name: "swimmingFishCompute")
    else {
      NSLog("[SwimmingFishRenderer] Failed to create Metal library or function")
      return
    }

    do {
      pipelineState = try device.makeComputePipelineState(function: kernelFunction)
    } catch {
      NSLog("[SwimmingFishRenderer] Failed to create pipeline: \(error)")
    }

    // 初始化小鱼
    initializeFishes()

    // 创建 buffer
    fishBuffer = device.makeBuffer(
      bytes: &fishes,
      length: MemoryLayout<Fish>.stride * fishCount,
      options: .storageModeShared
    )
  }

  private func initializeFishes() {
    fishes.removeAll()
    for i in 0..<fishCount {
      let fish = Fish(
        position: SIMD2<Float>(Float.random(in: 0.1...0.9), Float.random(in: 0.1...0.9)),
        velocity: SIMD2<Float>(Float.random(in: -0.005...0.005), Float.random(in: -0.005...0.005)),
        targetVelocity: SIMD2<Float>(0, 0),
        size: Float.random(in: 0.012...0.025),
        phase: Float(i) * 0.5
      )
      fishes.append(fish)
    }
  }

  func updateViewportSize(_ size: CGSize) {
    self.viewportSize = size
  }

  func update(currentTime: CFTimeInterval) {
    let inputState = InputEventManager.shared.getInputState(forScreen: screenIndex)

    // 检测新的点击（涟漪事件）
    let currentRippleCount = inputState.rippleEvents.count
    if currentRippleCount > lastRippleCount {
      // 有新点击，触发惊吓
      isScared = true
      scareTime = currentTime
    }
    lastRippleCount = currentRippleCount

    // 检查惊吓状态是否结束
    if isScared && (currentTime - scareTime) > scareDuration {
      isScared = false
    }

    let dt: Float = 1.0 / 30.0
    time += dt

    let mousePos = inputState.mousePosition
    let hasMouseActivity = inputState.hasMouseActivity

    // 更新每条鱼的状态
    for i in 0..<fishes.count {
      updateFish(index: i, mousePos: mousePos, hasMouseActivity: hasMouseActivity, dt: dt)
    }

    // 更新 buffer
    if let buffer = fishBuffer {
      memcpy(buffer.contents(), &fishes, MemoryLayout<Fish>.stride * fishCount)
    }
  }

  private func updateFish(index: Int, mousePos: SIMD2<Float>, hasMouseActivity: Bool, dt: Float) {
    var fish = fishes[index]

    // 计算到鼠标的向量
    let toMouse = mousePos - fish.position
    let distToMouse = length(toMouse)

    // 目标速度
    var targetVel = fish.velocity

    if isScared {
      // 惊吓状态：逃离鼠标
      if distToMouse > 0.01 {
        let escapeDir = -normalize(toMouse)
        targetVel = escapeDir * 0.005
      }
    } else if hasMouseActivity {
      // 有鼠标活动：强烈吸引向鼠标
      let attractDir = normalize(toMouse)

      if distToMouse > 0.08 {
        // 远处：直接向鼠标游去
        targetVel = attractDir * 0.004
      } else if distToMouse > 0.03 {
        // 中距离：吸引 + 少量切向
        let tangent = SIMD2<Float>(-attractDir.y, attractDir.x)
        targetVel = attractDir * 0.002 + tangent * 0.0008
      } else {
        // 非常近：盘旋
        let tangent = SIMD2<Float>(-toMouse.y, toMouse.x)
        targetVel = normalize(tangent) * 0.001
      }
    } else {
      // 无鼠标活动：极慢随机游弋
      if Float.random(in: 0...1) < 0.003 {
        let angle = Float.random(in: 0...(2 * .pi))
        targetVel = SIMD2<Float>(cos(angle), sin(angle)) * 0.0003
      }
    }

    // 边界反弹
    if fish.position.x < 0.05 { targetVel.x = abs(targetVel.x) + 0.001 }
    if fish.position.x > 0.95 { targetVel.x = -abs(targetVel.x) - 0.001 }
    if fish.position.y < 0.05 { targetVel.y = abs(targetVel.y) + 0.001 }
    if fish.position.y > 0.95 { targetVel.y = -abs(targetVel.y) - 0.001 }

    // 平滑过渡到目标速度 - 加快转向
    let smoothing: Float = isScared ? 0.12 : 0.06
    fish.velocity = mix(fish.velocity, targetVel, t: SIMD2<Float>(repeating: smoothing))

    // 限制速度
    let maxSpeed: Float = isScared ? 0.005 : 0.004
    let speed = length(fish.velocity)
    if speed > maxSpeed {
      fish.velocity = fish.velocity / speed * maxSpeed
    }

    // 更新位置
    fish.position += fish.velocity * dt * 60

    // 更新摆尾相位
    fish.phase += speed * 200 * dt

    fishes[index] = fish
  }

  func draw(in view: MTKView) {
    // 保护: 检查视图尺寸有效
    guard viewportSize.width > 0, viewportSize.height > 0 else { return }

    guard let drawable = view.currentDrawable,
      let pipelineState = pipelineState,
      let commandQueue = commandQueue,
      let fishBuffer = fishBuffer
    else { return }

    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeComputeCommandEncoder()
    else { return }

    let inputState = InputEventManager.shared.getInputState(forScreen: screenIndex)

    var shaderData = FishShaderData(
      fishCount: Int32(fishCount),
      mousePosition: inputState.mousePosition,
      hasMouseActivity: inputState.hasMouseActivity ? 1 : 0,
      isScared: isScared ? 1 : 0,
      time: time
    )

    encoder.setComputePipelineState(pipelineState)
    encoder.setTexture(drawable.texture, index: 0)
    encoder.setBuffer(fishBuffer, offset: 0, index: 0)
    encoder.setBytes(&shaderData, length: MemoryLayout<FishShaderData>.stride, index: 1)

    let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
    let threadGroups = MTLSize(
      width: (Int(viewportSize.width) + 15) / 16,
      height: (Int(viewportSize.height) + 15) / 16,
      depth: 1
    )

    encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    encoder.endEncoding()

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
