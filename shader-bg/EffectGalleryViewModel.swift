import AppKit
import Combine
import SwiftUI

class EffectGalleryViewModel: ObservableObject {
  @Published var effects: [VisualEffect] = []
  @Published var currentIndex: Int = 0
  @Published var generatingThumbnails: Set<Int> = []  // 正在生成缩略图的效果索引
  @Published var gpuUsageCache: [Int: Double] = [:]  // 记录每个效果的GPU开销
  @Published var loadingFromCDN: Set<Int> = []  // 正在从 CDN 加载的索引

  private var thumbnailCache: [Int: NSImage] = [:]
  private var cdnThumbnailCache: [Int: NSImage] = [:]  // CDN 加载的预览图缓存
  private var hasLocalThumbnail: Set<Int> = []  // 标记哪些有本地缩略图
  private let screenshotDirectory: URL?
  var onEffectSelected: ((Int) -> Void)?
  var onRefreshThumbnail: ((Int) -> Void)?  // 手动刷新缩略图的回调

  // CDN 基础 URL
  private let cdnBaseURL = "https://cos-sh.tiye.me/shader-bg/"
  private let cdnSuffix = "?imageMogr2/thumbnail/240x"

  // 效果名称到 CDN 图片名称的映射
  private let effectToCDNImage: [String: String] = [
    "noise_halo": "noise_halo.png",
    "particles_in_gravity": "particles_in_gravity.png",
    "rotating_lorenz": "rotating_lorenz.png",
    "rhombus": "rhombus.png",
    "apollian_twist": "apollian_twist.png",
    "clock": "clock.png",
    "waveform": "waveform.png",
    "vortex_street": "vortex_street.png",
    "rainbow_twister": "rainbow_twister.png",
    "star_travelling": "star_travelling.png",
    "sonata": "sonata.png",
    "mobius_flow": "mobius_flow.png",
    "bubbles": "bubbles.png",
    "glowy_orb": "glowy_orb.png",
    "city_of_kali": "city_of_kali.png",
    "stained_lights": "stained_lights.png",
    "tooned_cloud": "tooned_cloud.png",
    "simple_plasma": "simple_plasma.png",
    "warped_strings": "warped_strings.png",
    "galaxy_spiral": "galaxy_spiral.png",
    "cosmic_fireworks": "cosmic_fireworks.png",
    "ring_remix": "ring_remix.png",
    "red_blue_swirl": "red_blue_swirl.png",
    "smoke_ring": "smoke_ring.png",
    "MoonForest": "MoonForest.png",
    "RainbowRoad": "RainbowRoad.png",
    "NewtonCloud": "NewtonCloud.png",
    "PoincareHexagons": "PoincareHexagons.png",
    "PlasmaWaves": "PlasmaWaves.png",
    "HexagonalMandelbrot": "HexagonalMandelbrot.png",
    "Electricity": "Electricity.png",
    "Sunflower3": "Sunflower3.png",
    "LogZoomFlower": "LogZoomFlower.png",
    "Taiji": "Taiji.png",
    "JuliaSet": "JuliaSet.png",
    "Microwaves": "Microwaves.png",
    "MovingPixels": "MovingPixels.png",
    "InfiniteRing": "InfiniteRing.png",
    "Tesseract4D": "Tesseract4D.png",
    "SpiralStainedGlass": "SpiralStainedGlass.png",
    "DomainRepetition": "DomainRepetition.png",
    "NeonParallax": "NeonParallax.png",
    "DroppyThingies": "DroppyThingies.png",
    "FloatingBubbles": "FloatingBubbles.png",
    "Sunset925": "Sunset925.png",
    "TorusInterior": "TorusInterior.png",
    "RainRipples": "RainRipples.png",
    "ZoomedMaze": "ZoomedMaze.png",
    "ColorfulArcs": "ColorfulArcs.png",
    "Mandala": "Mandala.png",
    "SineMountains": "SineMountains.png",
    "geode_bg": "geode_bg.png",
    "butterfly_ai": "butterfly_ai.png",
    "hazy_morning_golf": "hazy_morning_golf.png",
    "surah_relax": "surah_relax.png",
    "korotkoe": "korotkoe.png",
    "petal_sphere": "petal_sphere.png",
    "spiral_for_windows": "spiral_for_windows.png",
    "sins_and_steps": "sins_and_steps.png",
    "hyperbolic_rings": "hyperbolic_rings.png",
    "shooting_stars": "shooting_stars.png",
    "event_horizon": "event_horizon.png",
    "golden_julia": "golden_julia.png",
    "moon_tree": "moon_tree.png",
    "year_of_truchets": "year_of_truchets.png",
    "newton_basins": "newton_basins.png",
    "mobius_knot": "mobius_knot.png",
    "pixellated_rain": "pixellated_rain.png",
    "sin_move": "sin_move.png",
    "world_tree": "world_tree.png",
    "sun_water": "sun_water.png",
    "mountain_waves": "mountain_waves.png",
  ]

  init() {
    self.effects = EffectManager.shared.availableEffects
    self.currentIndex = EffectManager.shared.currentEffectIndex

    // 获取截图目录
    if let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)
      .first
    {
      self.screenshotDirectory = picturesURL.appendingPathComponent("shader-bg")
    } else {
      self.screenshotDirectory = nil
    }

    loadThumbnails()
  }

  func selectEffect(at index: Int) {
    currentIndex = index
    onEffectSelected?(index)
  }

  // 手动刷新缩略图
  func refreshThumbnail(for index: Int) {
    // 移除旧的缩略图（不立即触发UI更新，等生成状态改变时自然更新）
    thumbnailCache.removeValue(forKey: index)

    // 触发重新生成
    onRefreshThumbnail?(index)
  }

  // 获取GPU开销文本
  func getGPUUsageText(for index: Int) -> String? {
    guard let usage = gpuUsageCache[index] else { return nil }
    return String(format: "GPU: %.0f%%", usage)
  }

  // 更新GPU开销数据（批量更新，减少UI刷新）
  func updateGPUUsage(for index: Int, usage: Double) {
    let oldValue = gpuUsageCache[index]
    gpuUsageCache[index] = usage

    // 只在值有明显变化时才触发更新（避免频繁刷新）
    if oldValue == nil || abs((oldValue ?? 0) - usage) > 0.5 {
      objectWillChange.send()
    }
  }

  // 开始生成缩略图（由AppDelegate调用）
  func startGeneratingThumbnail(for index: Int) {
    let wasEmpty = generatingThumbnails.isEmpty
    generatingThumbnails.insert(index)

    // 只在状态真正改变时触发更新
    if wasEmpty || !generatingThumbnails.contains(index) {
      objectWillChange.send()
    }
  }

  // 完成生成缩略图（由AppDelegate调用）
  func finishGeneratingThumbnail(for index: Int) {
    let hadValue = generatingThumbnails.contains(index)
    generatingThumbnails.remove(index)

    // 只在状态真正改变时触发更新
    if hadValue {
      objectWillChange.send()
    }
  }

  func getThumbnail(for index: Int) -> NSImage? {
    // 优先返回本地缩略图
    if let localThumbnail = thumbnailCache[index] {
      return localThumbnail
    }
    // 其次返回 CDN 预览图
    if let cdnThumbnail = cdnThumbnailCache[index] {
      return cdnThumbnail
    }
    return nil
  }

  // 检查是否有本地缩略图
  func hasLocalThumbnailFor(index: Int) -> Bool {
    return thumbnailCache[index] != nil
  }

  private func loadThumbnails() {
    // 初始化时不加载，只在 loadSavedThumbnails() 中加载已保存的缩略图
    NSLog("[EffectGallery] 等待加载已保存的缩略图")
  }

  // 从 CDN 加载预览图
  func loadCDNThumbnails() {
    for (index, effect) in effects.enumerated() {
      // 如果已有本地缩略图，跳过
      if thumbnailCache[index] != nil {
        continue
      }

      // 如果已有 CDN 缓存，跳过
      if cdnThumbnailCache[index] != nil {
        continue
      }

      // 查找 CDN 图片名称
      guard let imageName = effectToCDNImage[effect.name] else {
        NSLog("[EffectGallery] ⚠️ 未找到效果 '\(effect.name)' 的 CDN 图片映射")
        // 创建占位图
        cdnThumbnailCache[index] = createPlaceholderImage()
        continue
      }

      let urlString = cdnBaseURL + imageName + cdnSuffix
      guard let url = URL(string: urlString) else {
        NSLog("[EffectGallery] ❌ 无效的 URL: \(urlString)")
        cdnThumbnailCache[index] = createPlaceholderImage()
        continue
      }

      // 标记正在加载
      loadingFromCDN.insert(index)

      // 异步加载图片
      URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
        DispatchQueue.main.async {
          guard let self = self else { return }

          self.loadingFromCDN.remove(index)

          if let error = error {
            NSLog("[EffectGallery] ❌ 加载 CDN 图片失败 [\(effect.name)]: \(error.localizedDescription)")
            self.cdnThumbnailCache[index] = self.createPlaceholderImage()
            self.objectWillChange.send()
            return
          }

          guard let data = data, let image = NSImage(data: data) else {
            NSLog("[EffectGallery] ❌ 无法解析 CDN 图片数据 [\(effect.name)]")
            self.cdnThumbnailCache[index] = self.createPlaceholderImage()
            self.objectWillChange.send()
            return
          }

          // 缩放到合适尺寸
          let resized = self.resizeImage(image, to: CGSize(width: 130, height: 98))
          self.cdnThumbnailCache[index] = resized
          self.objectWillChange.send()
        }
      }.resume()
    }
  }

  // 创建浅蓝色渐变占位图
  private func createPlaceholderImage() -> NSImage {
    let size = CGSize(width: 130, height: 98)
    let image = NSImage(size: size)

    image.lockFocus()

    // 创建渐变
    let gradient = NSGradient(
      starting: NSColor(calibratedRed: 0.6, green: 0.8, blue: 1.0, alpha: 1.0),
      ending: NSColor(calibratedRed: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
    )
    gradient?.draw(in: NSRect(origin: .zero, size: size), angle: -45)

    image.unlockFocus()

    return image
  }

  func updateThumbnail(for index: Int, with image: NSImage) {
    // 4:3 比例，130x98（更小的卡片尺寸）
    let resized = resizeImage(image, to: CGSize(width: 130, height: 98))
    thumbnailCache[index] = resized
    objectWillChange.send()
  }

  private func resizeImage(_ image: NSImage, to targetSize: CGSize) -> NSImage {
    // 使用 CGImage 进行快速缩放
    guard let tiffData = image.tiffRepresentation,
      let bitmapImage = NSBitmapImageRep(data: tiffData),
      let cgImage = bitmapImage.cgImage
    else {
      // 如果快速路径失败，使用原图
      return image
    }

    // 计算缩放比例（保持4:3宽高比）
    let imageSize = image.size
    let widthRatio = targetSize.width / imageSize.width
    let heightRatio = targetSize.height / imageSize.height
    let scale = max(widthRatio, heightRatio)

    let scaledWidth = imageSize.width * scale
    let scaledHeight = imageSize.height * scale

    // 创建小的位图上下文
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard
      let context = CGContext(
        data: nil,
        width: Int(targetSize.width),
        height: Int(targetSize.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      return image
    }

    // 设置高质量插值
    context.interpolationQuality = .high

    // 居中绘制
    let x = (targetSize.width - scaledWidth) / 2
    let y = (targetSize.height - scaledHeight) / 2
    let rect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)

    context.draw(cgImage, in: rect)

    // 转换回 NSImage
    if let scaledCGImage = context.makeImage() {
      return NSImage(cgImage: scaledCGImage, size: targetSize)
    }

    return image
  }

  // 保存缩略图到文件系统
  func saveThumbnailToFile(for index: Int, image: NSImage) {
    guard let screenshotDirectory = screenshotDirectory else { return }

    // 创建 thumbnails 子目录
    let thumbnailsDir = screenshotDirectory.appendingPathComponent("thumbnails")
    try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)

    let effectName = effects[index].name
    let thumbnailPath = thumbnailsDir.appendingPathComponent("\(effectName).png")

    // 保存为 PNG
    if let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:])
    {
      try? pngData.write(to: thumbnailPath)
      NSLog("[EffectGallery] 已保存缩略图: \(thumbnailPath.lastPathComponent)")
    }
  }

  // 从文件系统加载保存的缩略图和GPU数据
  func loadSavedThumbnails() {
    guard let screenshotDirectory = screenshotDirectory else {
      // 没有本地目录，直接从 CDN 加载
      loadCDNThumbnails()
      return
    }

    let thumbnailsDir = screenshotDirectory.appendingPathComponent("thumbnails")
    var loadedCount = 0

    for (index, effect) in effects.enumerated() {
      let thumbnailPath = thumbnailsDir.appendingPathComponent("\(effect.name).png")
      if let image = NSImage(contentsOf: thumbnailPath) {
        thumbnailCache[index] = image
        loadedCount += 1
      }

      // 加载GPU数据
      let gpuDataPath = thumbnailsDir.appendingPathComponent("\(effect.name).gpu.txt")
      if let gpuData = try? String(contentsOf: gpuDataPath, encoding: .utf8),
        let usage = Double(gpuData.trimmingCharacters(in: .whitespacesAndNewlines))
      {
        gpuUsageCache[index] = usage
      }
    }

    NSLog("[EffectGallery] 已加载 \(loadedCount)/\(effects.count) 个本地缩略图")

    // 加载完本地缩略图后，从 CDN 加载缺失的预览图
    loadCDNThumbnails()

    objectWillChange.send()
  }

  // 保存GPU数据到文件
  func saveGPUUsageToFile(for index: Int, usage: Double) {
    guard let screenshotDirectory = screenshotDirectory else { return }

    let thumbnailsDir = screenshotDirectory.appendingPathComponent("thumbnails")
    try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)

    let effectName = effects[index].name
    let gpuDataPath = thumbnailsDir.appendingPathComponent("\(effectName).gpu.txt")

    let dataString = String(format: "%.1f", usage)
    try? dataString.write(to: gpuDataPath, atomically: true, encoding: .utf8)
  }
}
