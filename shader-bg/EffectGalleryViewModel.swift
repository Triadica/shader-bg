import AppKit
import Combine
import SwiftUI

class EffectGalleryViewModel: ObservableObject {
  @Published var effects: [VisualEffect] = []
  @Published var currentIndex: Int = 0

  private var thumbnailCache: [Int: NSImage] = [:]
  private let screenshotDirectory: URL?
  var onEffectSelected: ((Int) -> Void)?

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

  // 从文件系统加载保存的缩略图
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
    }

    NSLog("[EffectGallery] 已加载 \(loadedCount)/\(effects.count) 个缩略图")
    objectWillChange.send()
  }
}
