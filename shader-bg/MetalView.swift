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
    mtkView.autoResizeDrawable = true

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
    private var lastDrawableSize: CGSize = .zero
    private let lock = NSLock()

    // 渲染完成回调（用于精确截图时机）
    var onRenderComplete: (() -> Void)?
    private var framesRenderedSinceSwitch = 0
    private let minFramesBeforeCapture = 3  // 切换效果后至少渲染3帧再触发回调

    init(_ parent: MetalView) {
      self.parent = parent
      super.init()
      print("Coordinator [\(Unmanaged.passUnretained(self).toOpaque())] 已创建")
    }

    deinit {
      print("Coordinator [\(Unmanaged.passUnretained(self).toOpaque())] 开始释放...")

      lock.lock()
      isActive = false
      print("Coordinator [\(Unmanaged.passUnretained(self).toOpaque())] 已标记为不活跃")

      // 清理效果前先等待一小段时间，确保没有正在进行的绘制
      let effect = currentEffect
      currentEffect = nil
      lock.unlock()

      // 短暂等待，确保所有绘制操作完成
      usleep(10000)  // 10ms

      // 在锁外释放效果，避免死锁
      _ = effect

      print("Coordinator [\(Unmanaged.passUnretained(self).toOpaque())] 被释放")
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
      case "rhombus":
        newEffect = RhombusEffect()
      case "apollian_twist":
        newEffect = ApollianTwistEffect()
      case "clock":
        newEffect = ClockEffect()
      case "waveform":
        newEffect = WaveformEffect()
      case "vortex_street":
        newEffect = VortexStreetEffect()
      case "rainbow_twister":
        newEffect = RainbowTwisterEffect()
      case "star_travelling":
        newEffect = StarTravellingEffect()
      case "sonata":
        newEffect = SonataEffect()
      case "mobius_flow":
        newEffect = MobiusFlowEffect()
      case "bubbles":
        newEffect = BubblesUnderwaterEffect()
      case "glowy_orb":
        newEffect = GlowyOrbEffect()
      case "city_of_kali":
        newEffect = CityOfKaliEffect()
      case "stained_lights":
        newEffect = StainedLightsEffect()
      case "tooned_cloud":
        newEffect = ToonedCloudEffect()
      case "simple_plasma":
        newEffect = SimplePlasmaEffect()
      case "warped_strings":
        newEffect = WarpedStringsEffect()
      case "galaxy_spiral":
        newEffect = GalaxySpiralEffect()
      case "cosmic_fireworks":
        newEffect = CosmicFireworksEffect()
      case "ring_remix":
        newEffect = RingRemixEffect()
      case "red_blue_swirl":
        newEffect = RedBlueSwirlEffect()
      case "smoke_ring":
        newEffect = SmokeRingEffect()
      case "MoonForest":
        newEffect = MoonForestEffect()
      case "RainbowRoad":
        newEffect = RainbowRoadEffect()
      case "NewtonCloud":
        newEffect = NewtonCloudEffect()
      case "PoincareHexagons":
        newEffect = PoincareHexagonsEffect()
      case "PlasmaWaves":
        newEffect = PlasmaWavesEffect()
      case "HexagonalMandelbrot":
        newEffect = HexagonalMandelbrotEffect()
      case "Electricity":
        newEffect = ElectricityEffect()
      case "Sunflower3":
        newEffect = Sunflower3Effect()
      case "LogZoomFlower":
        newEffect = LogZoomFlowerEffect()
      case "Taiji":
        newEffect = TaijiEffect()
      case "JuliaSet":
        newEffect = JuliaSetEffect()
      case "Microwaves":
        newEffect = MicrowavesEffect()
      case "MovingPixels":
        newEffect = MovingPixelsEffect()
      case "InfiniteRing":
        newEffect = InfiniteRingEffect()
      case "Tesseract4D":
        newEffect = Tesseract4DEffect()
      case "SpiralStainedGlass":
        newEffect = SpiralStainedGlassEffect()
      case "DomainRepetition":
        newEffect = DomainRepetitionEffect()
      case "NeonParallax":
        newEffect = NeonParallaxEffect()
      case "DroppyThingies":
        newEffect = DroppyThingiesEffect()
      case "FloatingBubbles":
        newEffect = FloatingBubblesEffect()
      default:
        newEffect = NoiseHaloEffect()
      }

      newEffect.setup(device: device, size: size)
      currentEffect = newEffect

      // 重置帧计数
      framesRenderedSinceSwitch = 0

      print("切换到效果: \(newEffect.displayName), size: \(size)")
    }

    func setUpdateRate(_ rate: Double) {
      currentEffect?.setUpdateRate(rate)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
      if currentEffect == nil, let device = view.device {
        initializeEffect(device: device, size: size)
        lastDrawableSize = size
        return
      }

      // 判断是否为“显著尺寸变化”：尺寸变化超过 2pt 或者宽高比明显变化
      let wDelta = abs(size.width - lastDrawableSize.width)
      let hDelta = abs(size.height - lastDrawableSize.height)
      let ratioOld =
        (lastDrawableSize.width > 0 && lastDrawableSize.height > 0)
        ? (lastDrawableSize.width / lastDrawableSize.height) : 0
      let ratioNew = (size.width > 0 && size.height > 0) ? (size.width / size.height) : 0
      let ratioDelta = abs(ratioNew - ratioOld)

      if (wDelta > 2 || hDelta > 2) || ratioDelta > 0.01 {
        currentEffect?.handleSignificantResize(to: size)
      } else {
        currentEffect?.updateViewportSize(size)
      }

      lastDrawableSize = size
    }

    func draw(in view: MTKView) {
      // 尝试获取锁，如果无法获取则直接返回，避免阻塞
      guard lock.try() else {
        print("[DRAW] Coordinator [\(Unmanaged.passUnretained(self).toOpaque())] 锁繁忙，跳过此帧")
        return
      }
      defer { lock.unlock() }

      guard isActive else {
        print("[DRAW] Coordinator [\(Unmanaged.passUnretained(self).toOpaque())] 不活跃，跳过绘制")
        return
      }

      // 确保效果已初始化
      if currentEffect == nil, let device = view.device, view.drawableSize.width > 0 {
        initializeEffect(device: device, size: view.drawableSize)
      }

      // 安全检查：如果 coordinator 正在被释放，立即返回
      guard currentEffect != nil, isActive else { return }

      let currentTime = CACurrentMediaTime()
      currentEffect?.update(currentTime: currentTime)
      currentEffect?.draw(in: view)

      // 渲染完成后的回调处理
      framesRenderedSinceSwitch += 1
      if framesRenderedSinceSwitch == minFramesBeforeCapture, let callback = onRenderComplete {
        // 只触发一次回调
        onRenderComplete = nil
        // 在主线程延迟一点点执行，确保drawable已经present
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
          callback()
        }
      }
    }

    // 安全停止方法：在清理前调用
    func safeStop() {
      print("[STOP] Coordinator [\(Unmanaged.passUnretained(self).toOpaque())] 开始安全停止...")
      lock.lock()
      isActive = false

      // 清理当前效果
      currentEffect = nil
      lock.unlock()

      // 等待可能正在进行的绘制完成
      usleep(50000)  // 50ms - 增加等待时间
      print("[STOP] Coordinator [\(Unmanaged.passUnretained(self).toOpaque())] 已停止")
    }
  }
}
