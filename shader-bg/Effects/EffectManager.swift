//
//  EffectManager.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//  Forked from https://www.shadertoy.com/view/NlSyRd

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
    NSLog("[EffectManager] 📋 Registering effects...")
    availableEffects = [
      NoiseHaloEffect(),
      ParticlesInGravityEffect(),
      RotatingLorenzEffect(),
      RhombusEffect(),
      ApollianTwistEffect(),
      ClockEffect(),
      WaveformEffect(),
      VortexStreetEffect(),
      RainbowTwisterEffect(),
      StarTravellingEffect(),
      SonataEffect(),
      MobiusFlowEffect(),
      BubblesUnderwaterEffect(),
      GlowyOrbEffect(),
      CityOfKaliEffect(),
      StainedLightsEffect(),
      ToonedCloudEffect(),
      SimplePlasmaEffect(),
      WarpedStringsEffect(),
      GalaxySpiralEffect(),
      CosmicFireworksEffect(),
      RingRemixEffect(),
      RedBlueSwirlEffect(),
      SmokeRingEffect(),
      MoonForestEffect(),
      RainbowRoadEffect(),
      NewtonCloudEffect(),
      PoincareHexagonsEffect(),
      PlasmaWavesEffect(),
      HexagonalMandelbrotEffect(),
      ElectricityEffect(),
      Sunflower3Effect(),
      LogZoomFlowerEffect(),
      TaijiEffect(),
      JuliaSetEffect(),
      MicrowavesEffect(),
      MovingPixelsEffect(),
      InfiniteRingEffect(),
      Tesseract4DEffect(),
      SpiralStainedGlassEffect(),
      DomainRepetitionEffect(),
      NeonParallaxEffect(),
      DroppyThingiesEffect(),
      FloatingBubblesEffect(),
      Sunset925Effect(),
      TorusInteriorEffect(),
      RainRipplesEffect(),
      ZoomedMazeEffect(),
      ColorfulArcsEffect(),
      MandalaEffect(),
      SineMountainsEffect(),
      GeodeBGEffect(),
      ButterflyAIEffect(),
      HazyMorningGolfEffect(),
      SurahRelaxEffect(),
      KorotkoeEffect(),
      PetalSphereEffect(),
      SpiralForWindowsEffect(),
      SinsAndStepsEffect(),
      HyperbolicRingsEffect(),
      ShootingStarsEffect(),
      EventHorizonEffect(),
      GoldenJuliaEffect(),
      MoonTreeEffect(),
      YearOfTruchetsEffect(),
      NewtonBasinsEffect(),
      MobiusKnotEffect(),
      PixellatedRainEffect(),
      SinMoveEffect(),
      WorldTreeEffect(),
      SunWaterEffect(),
      MountainWavesEffect(),
    ]

    NSLog("[EffectManager] ✅ Registered \(availableEffects.count) effects")
    for (index, effect) in availableEffects.enumerated() {
      NSLog("[EffectManager]   [\(index)] \(effect.displayName) (\(effect.name))")
    }

    // 检查环境变量 SHADER_BG_EFFECT 来决定默认效果
    // 可选值: "noise", "gravity", "lorenz", "rhombus", "apollian", "clock", "waveform", "vortex", "rainbow", "star", "sonata", "mobius", "bubbles", "glowy", "kali", "stained", "cloud", "plasma", "warped", "galaxy", "cosmic", "ring", "swirl", "smoke", "moon", "road", "newton", "poincare", "waves"
    var defaultIndex = availableEffects.count - 1  // 默认为最后一个效果（方便调试）

    if let effectEnv = ProcessInfo.processInfo.environment["SHADER_BG_EFFECT"] {
      NSLog("[EffectManager] 🔍 SHADER_BG_EFFECT = '\(effectEnv)'")
      switch effectEnv.lowercased() {
      case "noise":
        defaultIndex = 0
      case "gravity":
        defaultIndex = 1
      case "lorenz":
        defaultIndex = 2
      case "rhombus":
        defaultIndex = 3
      case "apollian":
        defaultIndex = 4
      case "clock":
        defaultIndex = 5
      case "waveform":
        defaultIndex = 6
      case "vortex":
        defaultIndex = 7
      case "rainbow":
        defaultIndex = 8
      case "star":
        defaultIndex = 9
      case "sonata":
        defaultIndex = 10
      case "mobius":
        defaultIndex = 11
      case "bubbles":
        defaultIndex = 12
      case "glowy":
        defaultIndex = 13
      case "kali":
        defaultIndex = 14
      case "stained":
        defaultIndex = 15
      case "cloud":
        defaultIndex = 16
      case "plasma":
        defaultIndex = 17
      case "warped":
        defaultIndex = 18
      case "galaxy":
        defaultIndex = 19
      case "cosmic":
        defaultIndex = 20
      case "ring":
        defaultIndex = 21
      case "swirl":
        defaultIndex = 22
      case "smoke":
        defaultIndex = 23
      case "moon":
        defaultIndex = 24
      case "road":
        defaultIndex = 25
      case "newton":
        defaultIndex = 26
      case "poincare":
        defaultIndex = 27
      case "waves":
        defaultIndex = 28
      case "hexagonal", "mandelbrot":
        defaultIndex = 29
      case "electricity":
        defaultIndex = 30
      case "sunflower3":
        defaultIndex = 31
      case "logzoom", "logzoomflower":
        defaultIndex = 32
      case "taiji":
        defaultIndex = 33
      case "julia", "juliaset":
        defaultIndex = 34
      case "microwaves", "micro":
        defaultIndex = 35
      case "movingpixels", "pixels", "hive":
        defaultIndex = 36
      case "infiniteering", "infiniring":
        defaultIndex = 37
      case "tesseract", "tesseract4d", "hypercube", "4d":
        defaultIndex = 38
      case "spiralstainedglass", "spiral", "spiralglass", "stainedglass":
        defaultIndex = 39
      case "domainrepetition", "domain", "repetition", "raymarch":
        defaultIndex = 40
      case "neonparallax", "neon", "parallax":
        defaultIndex = 41
      case "droppythingies", "droppy", "drops", "thingies":
        defaultIndex = 42
      case "floatingbubbles", "floating", "floaty":
        defaultIndex = 43
      case "sunset925", "sunset", "925":
        defaultIndex = 44
      case "torusinterior", "torus", "interior":
        defaultIndex = 45
      case "rainripples", "rain", "ripples":
        defaultIndex = 46
      case "zoomedmaze", "zoomed", "maze":
        defaultIndex = 47
      case "colorfularcs", "colorful", "arcs":
        defaultIndex = 48
      case "mandala":
        defaultIndex = 49
      case "sinemountains", "sine", "mountains":
        defaultIndex = 50
      case "geodebg", "geode":
        defaultIndex = 51
      case "butterflyai", "butterfly", "ai":
        defaultIndex = 52
      case "hazymorninggolf", "hazy", "morning", "golf":
        defaultIndex = 53
      case "surahrelax", "surah", "relax":
        defaultIndex = 54
      case "korotkoe":
        defaultIndex = 55
      case "petalsphere", "petal", "sphere":
        defaultIndex = 56
      case "spiralforwindows", "spiral", "windows":
        defaultIndex = 57
      case "sinsandsteps", "sins", "steps":
        defaultIndex = 58
      case "hyperbolicrings", "hyperbolic", "rings":
        defaultIndex = 59
      case "shootingstars", "shooting", "stars":
        defaultIndex = 60
      case "eventhorizon", "event", "horizon", "blackhole":
        defaultIndex = 61
      case "goldenjulia", "golden", "julia":
        defaultIndex = 62
      case "moontree", "moon", "tree", "moonforest":
        defaultIndex = 63
      case "yearoftruchets", "truchets", "truchet", "year":
        defaultIndex = 64
      case "newtonbasins", "basins", "newtonfractal":
        defaultIndex = 65
      case "mobiusknot", "mobius", "knot", "cosmicknot":
        defaultIndex = 66
      case "pixellatedrain", "pixelrain", "rain", "matrixrain":
        defaultIndex = 67
      case "sinmove", "sinwave", "sinwaves", "wavemove":
        defaultIndex = 68
      case "worldtree", "tree", "world", "magictree":
        defaultIndex = 69
      case "sunwater", "sun", "water", "sunset", "sunwaves":
        defaultIndex = 70
      case "mountainwaves", "mountain", "mountains", "mountainwave":
        defaultIndex = 71
      default:
        NSLog(
          "[EffectManager] ⚠️ Unknown SHADER_BG_EFFECT value: \(effectEnv), using default (lorenz)")
        print("Unknown SHADER_BG_EFFECT value: \(effectEnv), using default (lorenz)")
      }
      NSLog("[EffectManager] ➡️ Selected effect index: \(defaultIndex)")
    } else {
      NSLog("[EffectManager] ℹ️ No SHADER_BG_EFFECT set, using default index \(defaultIndex)")
    }

    // 设置默认效果
    if !availableEffects.isEmpty {
      let safeIndex = min(max(defaultIndex, 0), availableEffects.count - 1)
      currentEffect = availableEffects[safeIndex]
      currentEffectIndex = safeIndex
      NSLog(
        "[EffectManager] 🎯 Current effect set to: [\(safeIndex)] \(currentEffect?.displayName ?? "nil")"
      )
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
