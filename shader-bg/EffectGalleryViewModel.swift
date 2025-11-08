import AppKit
import Combine
import SwiftUI

class EffectGalleryViewModel: ObservableObject {
  @Published var effects: [VisualEffect] = []
  @Published var currentIndex: Int = 0
  @Published var generatingThumbnails: Set<Int> = []  // 正在生成缩略图的效果索引
  @Published var gpuUsageCache: [Int: Double] = [:]  // 记录每个效果的GPU开销

  private var thumbnailCache: [Int: NSImage] = [:]
  private let screenshotDirectory: URL?
  var onEffectSelected: ((Int) -> Void)?
  var onRefreshThumbnail: ((Int) -> Void)?  // 手动刷新缩略图的回调

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
    return thumbnailCache[index]
  }

  private func loadThumbnails() {
    // 初始化时不加载，只在 loadSavedThumbnails() 中加载已保存的缩略图
    NSLog("[EffectGallery] 等待加载已保存的缩略图")
  }

  func updateThumbnail(for index: Int, with image: NSImage) {
    // 4:3 比例，130x98（更小的卡片尺寸）
    let resized = resizeImage(image, to: CGSize(width: 130, height: 98))
    thumbnailCache[index] = resized
    objectWillChange.send()
  }

  private func resizeImage(_ image: NSImage, to targetSize: CGSize) -> NSImage {
    let newImage = NSImage(size: targetSize)
    newImage.lockFocus()

    // 保持4:3宽高比，填充整个区域
    let imageSize = image.size
    let widthRatio = targetSize.width / imageSize.width
    let heightRatio = targetSize.height / imageSize.height
    let scale = max(widthRatio, heightRatio)

    let scaledWidth = imageSize.width * scale
    let scaledHeight = imageSize.height * scale

    let x = (targetSize.width - scaledWidth) / 2
    let y = (targetSize.height - scaledHeight) / 2

    let rect = NSRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
    image.draw(
      in: rect, from: NSRect(origin: .zero, size: imageSize), operation: .copy, fraction: 1.0)

    newImage.unlockFocus()
    return newImage
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
    guard let screenshotDirectory = screenshotDirectory else { return }

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

    NSLog("[EffectGallery] 已加载 \(loadedCount)/\(effects.count) 个缩略图")
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
