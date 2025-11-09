//
//  AppDelegate.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Cocoa
import CoreGraphics
import MetalKit
import SwiftUI
import UniformTypeIdentifiers

private func activeDisplayIDs() -> [CGDirectDisplayID] {
  var displayCount: UInt32 = 0
  var error = CGGetActiveDisplayList(0, nil, &displayCount)
  guard error == .success, displayCount > 0 else {
    NSLog("[SCREENSHOT] 无法获取显示器数量，错误码: \(error.rawValue)")
    return []
  }

  var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
  error = CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)
  guard error == .success else {
    NSLog("[SCREENSHOT] 无法获取显示器列表，错误码: \(error.rawValue)")
    return []
  }

  return Array(displayIDs.prefix(Int(displayCount)))
}

extension NSScreen {
  fileprivate var displayID: CGDirectDisplayID? {
    deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
  }
}

private struct CaptureTarget {
  let displayID: CGDirectDisplayID
  let fileURL: URL
  let displayIndex: Int
  let screenName: String
}

class AppDelegate: NSObject, NSApplicationDelegate {
  private let captureQueue = DispatchQueue(
    label: "com.triadica.shader-bg.capture",
    qos: .userInitiated
  )
  private var isCaptureInProgress = false
  private static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "mm-ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    return formatter
  }()

  var wallpaperWindows: [WallpaperWindow] = []
  var metalViews: [MTKView] = []  // 保存 MTKView 的引用
  var statusItem: NSStatusItem?
  var screenshotTimer: Timer?
  var screenshotDirectory: URL?
  private var hasLoggedScreenPermissionWarning = false
  private var hasRequestedScreenPermission = false  // 标记是否已请求过权限
  private var cachedScreenRecordingPermission: Bool?
  private var lastPermissionCheckDate: Date = .distantPast
  private let permissionCheckInterval: TimeInterval = 60
  private var isSessionActive = true
  private var pendingSessionResumeWorkItem: DispatchWorkItem?

  // 效果图库相关
  var galleryWindow: NSWindow?
  var galleryViewModel: EffectGalleryViewModel?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    setupScreenshotDirectory()
    setupWallpaperWindows()
    setupMenuBar()
    setupPerformanceMonitoring()
    setupScreenshotTimer()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    workspaceCenter.addObserver(
      self,
      selector: #selector(sessionDidResignActive(_:)),
      name: NSWorkspace.sessionDidResignActiveNotification,
      object: nil
    )
    workspaceCenter.addObserver(
      self,
      selector: #selector(sessionDidBecomeActive(_:)),
      name: NSWorkspace.sessionDidBecomeActiveNotification,
      object: nil
    )
  }

  func setupScreenshotDirectory() {
    // 使用 ~/Pictures/shader-bg 目录
    guard
      let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
    else {
      NSLog("[SCREENSHOT] 无法定位 Pictures 目录")
      return
    }

    screenshotDirectory = picturesURL.appendingPathComponent("shader-bg")

    do {
      guard let screenshotDirectory else { return }
      try FileManager.default.createDirectory(
        at: screenshotDirectory, withIntermediateDirectories: true)
      NSLog("[SCREENSHOT] 截图目录已创建: \(screenshotDirectory.path)")
    } catch {
      NSLog("[SCREENSHOT] 创建截图目录失败: \(error)")
    }
  }

  func setupScreenshotTimer() {
    guard isSessionActive else {
      NSLog("[SCREENSHOT] 会话不活跃，暂不启动截图定时器")
      return
    }

    guard checkScreenRecordingPermission(force: true) else {
      NSLog("[SCREENSHOT] 未启用定时器：缺少屏幕录制权限")
      return
    }

    NSLog("[SCREENSHOT] 设置截图定时器，每5秒执行一次")
    // 每5秒截图一次
    screenshotTimer = Timer.scheduledTimer(
      withTimeInterval: 5.0,
      repeats: true
    ) { [weak self] _ in
      NSLog("[SCREENSHOT] 定时器触发")
      self?.captureAndSetWallpaper()
    }
    if let timer = screenshotTimer {
      RunLoop.main.add(timer, forMode: .common)
    }
  }

  @objc func captureAndSetWallpaper() {
    captureQueue.async { [weak self] in
      guard let self = self else { return }
      guard self.isSessionActive else {
        NSLog("[SCREENSHOT] 会话不活跃，跳过本轮截图")
        return
      }
      if self.isCaptureInProgress {
        NSLog("[SCREENSHOT] 上一次截图尚未完成，跳过本轮触发")
        return
      }

      self.isCaptureInProgress = true
      defer { self.isCaptureInProgress = false }

      self.performCaptureCycle()
    }
  }

  private func performCaptureCycle() {
    guard isSessionActive else {
      NSLog("[SCREENSHOT] 会话不活跃，跳过截图循环")
      return
    }
    guard let screenshotDirectory = screenshotDirectory else {
      NSLog("[SCREENSHOT] 错误：截图目录未初始化")
      return
    }

    guard checkScreenRecordingPermission() else {
      stopScreenshotTimer(reason: "缺少屏幕录制权限")
      return
    }

    let timestamp = Self.timestampFormatter.string(from: Date())
    let targets = DispatchQueue.main.sync {
      self.prepareCaptureTargets(in: screenshotDirectory, timestamp: timestamp)
    }

    guard !targets.isEmpty else {
      NSLog("[SCREENSHOT] 没有可用的截图目标，跳过本轮")
      return
    }

    NSLog("[SCREENSHOT] 开始截图，本轮屏幕数量: \(targets.count)")

    var successfulTargets: [CaptureTarget] = []
    let fileManager = FileManager.default

    for target in targets {
      do {
        if fileManager.fileExists(atPath: target.fileURL.path) {
          try fileManager.removeItem(at: target.fileURL)
        }
      } catch {
        NSLog("[SCREENSHOT] 无法删除旧文件 \(target.fileURL.path): \(error)")
      }

      // 使用 target.displayIndex 作为 wallpaperWindows 数组的索引（从 0 开始）
      let displayNumber = target.displayIndex

      if captureDisplay(
        to: target.fileURL,
        displayNumber: displayNumber
      ) {
        NSLog("[SCREENSHOT] ✅ 截图已保存: \(target.fileURL.path)")
        successfulTargets.append(target)
      } else {
        NSLog(
          "[SCREENSHOT] ❌ 截取屏幕失败: display=\(displayNumber), name=\(target.screenName)"
        )
      }
    }

    cleanupOldScreenshots()

    if successfulTargets.isEmpty {
      NSLog("[SCREENSHOT] 本轮截图全部失败，跳过壁纸更新")
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      for target in successfulTargets {
        guard
          let screen = NSScreen.screens.first(where: { $0.displayID == target.displayID })
        else {
          NSLog("[SCREENSHOT] 未找到匹配的屏幕，跳过壁纸设置: \(target.screenName)")
          continue
        }
        self.setDesktopWallpaper(target.fileURL, for: screen)
      }
    }
  }

  @discardableResult
  private func checkScreenRecordingPermission(force: Bool = false) -> Bool {
    if #available(macOS 10.15, *) {
      let now = Date()
      if !force,
        let cached = cachedScreenRecordingPermission,
        now.timeIntervalSince(lastPermissionCheckDate) < permissionCheckInterval
      {
        return cached
      }

      let granted = CGPreflightScreenCaptureAccess()
      cachedScreenRecordingPermission = granted
      lastPermissionCheckDate = now
      if granted {
        hasLoggedScreenPermissionWarning = false
        hasRequestedScreenPermission = false  // 重置，以便下次失去权限时可以重新请求
        return true
      }

      // 如果没有权限且还未请求过，则请求一次
      if !hasRequestedScreenPermission {
        hasRequestedScreenPermission = true
        NSLog("[SCREENSHOT] 正在请求屏幕录制权限...")
        let requested = CGRequestScreenCaptureAccess()
        if requested {
          NSLog("[SCREENSHOT] 屏幕录制权限请求已发送，请在系统设置中授权后重启应用")
        } else {
          NSLog("[SCREENSHOT] 屏幕录制权限请求失败或已被拒绝")
        }
      }

      // 只在第一次失败时记录警告
      if !hasLoggedScreenPermissionWarning {
        hasLoggedScreenPermissionWarning = true
        NSLog(
          "[SCREENSHOT] ⚠️ 未检测到屏幕录制权限，已跳过自动截图。请前往 \"系统设置 > 隐私与安全性 > 屏幕录制\" 中勾选 shader-bg，并重新启动应用后再试。"
        )
      }
      return false
    }

    return true
  }

  private func prepareCaptureTargets(in directory: URL, timestamp: String) -> [CaptureTarget] {
    guard isSessionActive else {
      NSLog("[SCREENSHOT] 会话不活跃，跳过截图目标准备")
      return []
    }
    let screens = NSScreen.screens
    guard !screens.isEmpty else {
      NSLog("[SCREENSHOT] 当前没有可用屏幕")
      return []
    }

    let displayIDs = activeDisplayIDs()
    guard !displayIDs.isEmpty else {
      NSLog("[SCREENSHOT] 无法获取有效的显示器列表")
      return []
    }

    let targets = screens.compactMap { screen -> CaptureTarget? in
      guard let displayID = screen.displayID else {
        NSLog("[SCREENSHOT] 未找到屏幕 displayID: \(screen)")
        return nil
      }

      guard let index = displayIDs.firstIndex(of: displayID) else {
        NSLog("[SCREENSHOT] 显示器 ID \(displayID) 不在当前活动显示器列表中")
        return nil
      }

      guard isDisplayUsable(displayID) else {
        NSLog("[SCREENSHOT] 显示器 ID \(displayID) 当前不可用，跳过")
        return nil
      }

      let filename = "screen-\(index)-\(timestamp).png"
      let fileURL = directory.appendingPathComponent(filename)
      return CaptureTarget(
        displayID: displayID,
        fileURL: fileURL,
        displayIndex: index,
        screenName: screen.localizedName
      )
    }.sorted { $0.displayIndex < $1.displayIndex }

    return targets
  }

  // 快速截取缩略图（使用临时文件但立即删除）
  private func captureThumbnail(for displayNumber: Int) -> NSImage? {
    guard displayNumber < wallpaperWindows.count else {
      NSLog("[SCREENSHOT] 无效的显示器索引: \(displayNumber)")
      return nil
    }

    // 直接从 MTKView 读取当前帧的纹理
    let window = wallpaperWindows[displayNumber]
    if let hostingView = window.contentView as? NSHostingView<WallpaperContentView>,
      let mtkView = findMTKView(in: hostingView),
      let drawable = mtkView.currentDrawable
    {
      let texture = drawable.texture
      // 从 Metal 纹理创建 CGImage
      if let cgImage = createCGImage(from: texture) {
        let nsImage = NSImage(
          cgImage: cgImage, size: NSSize(width: texture.width, height: texture.height))
        NSLog("[SCREENSHOT] ✅ 从 Metal 纹理成功创建缩略图")
        return nsImage
      }
    }

    NSLog("[SCREENSHOT] ❌ 无法从 Metal 纹理创建缩略图")
    return nil
  }

  // 从 Metal 纹理创建 CGImage
  private func createCGImage(from texture: MTLTexture) -> CGImage? {
    let width = texture.width
    let height = texture.height
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bufferSize = bytesPerRow * height

    // 创建缓冲区来存储像素数据
    var pixelData = [UInt8](repeating: 0, count: bufferSize)

    // 从纹理读取数据
    let region = MTLRegionMake2D(0, 0, width, height)
    texture.getBytes(&pixelData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

    // 创建 CGImage
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

    guard let dataProvider = CGDataProvider(data: Data(pixelData) as CFData),
      let cgImage = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: dataProvider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    else {
      return nil
    }

    return cgImage
  }

  private func captureDisplay(to destinationURL: URL, displayNumber: Int) -> Bool {
    // 使用窗口ID来截取特定窗口的内容,而不是整个显示器
    guard displayNumber < wallpaperWindows.count else {
      NSLog("[SCREENSHOT] 无效的显示器索引: \(displayNumber)")
      return false
    }

    let window = wallpaperWindows[displayNumber]
    let windowNumber = window.windowNumber

    let process = Process()
    process.launchPath = "/usr/sbin/screencapture"
    process.arguments = [
      "-x",  // 不播放截图声音
      "-t", "png",  // PNG 格式
      "-l", String(windowNumber),  // 截取特定窗口
      destinationURL.path,
    ]

    let pipe = Pipe()
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      NSLog("[SCREENSHOT] screencapture 启动失败: \(error)")
      return false
    }

    if process.terminationStatus != 0 {
      let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
      if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
        NSLog("[SCREENSHOT] screencapture 错误: \(errorString)")
      }
      return false
    }

    return true
  }

  func setDesktopWallpaper(_ imageURL: URL, for screen: NSScreen) {
    guard isSessionActive else {
      NSLog("[SCREENSHOT] 会话不活跃，跳过壁纸更新")
      return
    }
    guard let displayID = screen.displayID else {
      NSLog("[SCREENSHOT] ❌ 设置桌面壁纸失败：屏幕缺少 displayID")
      return
    }

    guard isDisplayUsable(displayID) else {
      NSLog("[SCREENSHOT] SKIP 显示器 ID \(displayID) 已失效或离线，跳过壁纸更新")
      return
    }

    do {
      try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
      NSLog("[SCREENSHOT] ✅ 已设置桌面壁纸: \(imageURL.lastPathComponent) for \(screen.localizedName)")

      // 同时保存为当前效果的缩略图
      saveThumbnailFromScreenshot(imageURL)
    } catch {
      NSLog("[SCREENSHOT] ❌ 设置桌面壁纸失败: \(error)")
    }
  }

  private func saveThumbnailFromScreenshot(_ imageURL: URL) {
    guard let image = NSImage(contentsOf: imageURL) else { return }

    let currentIndex = EffectManager.shared.currentEffectIndex
    galleryViewModel?.updateThumbnail(for: currentIndex, with: image)
    galleryViewModel?.saveThumbnailToFile(for: currentIndex, image: image)
  }

  // 为指定效果索引捕获缩略图
  // 设置渲染完成回调，精确触发截图
  private func setupRenderCompleteCallback(for index: Int) {
    // 找到第一个可见的壁纸窗口并设置回调
    for window in wallpaperWindows {
      guard window.isVisible else { continue }

      if let hostingView = window.contentView as? NSHostingView<WallpaperContentView>,
        let mtkView = findMTKView(in: hostingView),
        let delegate = mtkView.delegate as? MetalView.Coordinator
      {

        NSLog("[EffectGallery] 🎯 设置渲染完成回调，等待效果 [\(index)] 渲染...")

        // 设置回调：当渲染了3帧后自动触发截图
        delegate.onRenderComplete = { [weak self] in
          NSLog("[EffectGallery] ✅ 效果 [\(index)] 渲染完成，开始截图")
          self?.captureThumbnailForEffect(at: index)
        }

        break
      }
    }
  }

  private func captureThumbnailForEffect(at index: Int) {
    // 双重确认当前显示的确实是目标效果
    guard EffectManager.shared.currentEffectIndex == index else {
      NSLog(
        "[EffectGallery] ⚠️ 跳过截图：当前效果索引(\(EffectManager.shared.currentEffectIndex))与目标索引(\(index))不匹配"
      )
      return
    }

    guard screenshotDirectory != nil else { return }

    // 在主线程标记开始生成缩略图
    DispatchQueue.main.async { [weak self] in
      self?.galleryViewModel?.startGeneratingThumbnail(for: index)
    }

    let effectName = EffectManager.shared.availableEffects[index].name
    NSLog("[EffectGallery] 📸 开始为效果 [\(index)] \(effectName) 截图和GPU采样（后台执行）...")

    // 在后台线程执行耗时的GPU采样和截图操作
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }

      // 采样GPU使用率（减少采样次数和间隔，加快速度）
      var gpuSamples: [Double] = []
      NSLog("[EffectGallery] 📊 开始快速采样GPU使用率...")

      for i in 0..<6 {  // 减少到6次采样
        // 强制触发性能监控更新
        PerformanceManager.shared.checkResourceUsage()

        let usage = PerformanceManager.shared.lastGPUUsage
        gpuSamples.append(usage)

        if i < 5 {
          Thread.sleep(forTimeInterval: 0.3)  // 减少到0.3秒间隔
        }

        if (i + 1) % 2 == 0 {
          NSLog("[EffectGallery] 📊 采样进度: \(i + 1)/6, 当前值: %.1f%%", usage)
        }
      }

      // 排序并去除最高和最低的1个值，取中间值的平均
      let sortedSamples = gpuSamples.sorted()
      let trimmedSamples =
        sortedSamples.count > 2
        ? Array(sortedSamples.dropFirst(1).dropLast(1))
        : sortedSamples

      let avgGPU =
        trimmedSamples.isEmpty
        ? 0.0
        : trimmedSamples.reduce(0, +) / Double(trimmedSamples.count)

      NSLog(
        "[EffectGallery] 📊 GPU采样完成: 平均值=%.1f%%, 样本数=%d, 范围=[%.1f%% - %.1f%%]",
        avgGPU, trimmedSamples.count, sortedSamples.first ?? 0, sortedSamples.last ?? 0)

      // 再次确认索引没有变化
      guard EffectManager.shared.currentEffectIndex == index else {
        NSLog("[EffectGallery] ⚠️ GPU采样期间效果已切换，取消截图")
        DispatchQueue.main.async { [weak self] in
          self?.galleryViewModel?.finishGeneratingThumbnail(for: index)
        }
        return
      }

      // 快速截取缩略图（无需保存临时文件）
      NSLog("[EffectGallery] 📸 快速截取缩略图...")
      if let image = self.captureThumbnail(for: 0) {
        NSLog("[EffectGallery] ✅ 截图成功, GPU: %.1f%%", avgGPU)

        // 再次确认索引
        guard EffectManager.shared.currentEffectIndex == index else {
          NSLog("[EffectGallery] ⚠️ 截图过程中效果已切换，丢弃此截图")
          DispatchQueue.main.async { [weak self] in
            self?.galleryViewModel?.finishGeneratingThumbnail(for: index)
          }
          return
        }

        // 在后台处理和保存图片
        // 切换到主线程更新UI
        DispatchQueue.main.async { [weak self] in
          self?.galleryViewModel?.updateThumbnail(for: index, with: image)
          self?.galleryViewModel?.updateGPUUsage(for: index, usage: avgGPU)
        }

        // 后台保存文件
        self.galleryViewModel?.saveThumbnailToFile(for: index, image: image)
        self.galleryViewModel?.saveGPUUsageToFile(for: index, usage: avgGPU)

        NSLog("[EffectGallery] 💾 缩略图和GPU数据已保存到文件系统")

        // 标记完成
        DispatchQueue.main.async { [weak self] in
          self?.galleryViewModel?.finishGeneratingThumbnail(for: index)
        }
      } else {
        NSLog("[EffectGallery] ❌ 截图失败，效果索引: \(index)")
        DispatchQueue.main.async { [weak self] in
          self?.galleryViewModel?.finishGeneratingThumbnail(for: index)
        }
      }
    }
  }

  func cleanupOldScreenshots() {
    guard let screenshotDirectory = screenshotDirectory else { return }

    do {
      let fileURLs = try FileManager.default.contentsOfDirectory(
        at: screenshotDirectory,
        includingPropertiesForKeys: [.creationDateKey],
        options: [.skipsHiddenFiles]
      )

      // 按创建时间排序
      let sortedFiles = fileURLs.sorted { url1, url2 in
        let date1 =
          (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
        let date2 =
          (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
        return date1 > date2
      }

      // 删除超过10个的旧文件
      if sortedFiles.count > 10 {
        for fileURL in sortedFiles.dropFirst(10) {
          try FileManager.default.removeItem(at: fileURL)
          NSLog("[SCREENSHOT] 已删除旧截图: \(fileURL.lastPathComponent)")
        }
      }
    } catch {
      NSLog("[SCREENSHOT] 清理旧截图失败: \(error)")
    }
  }

  private func stopScreenshotTimer(reason: String? = nil) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      if let timer = self.screenshotTimer {
        timer.invalidate()
        self.screenshotTimer = nil
        if let reason {
          NSLog("[SCREENSHOT] 已停止截图定时器：\(reason)")
        } else {
          NSLog("[SCREENSHOT] 已停止截图定时器")
        }
      }
    }
  }

  private func isDisplayUsable(_ displayID: CGDirectDisplayID) -> Bool {
    let isActive = CGDisplayIsActive(displayID) != 0
    let isOnline = CGDisplayIsOnline(displayID) != 0
    let isAsleep = CGDisplayIsAsleep(displayID) != 0
    return isActive && isOnline && !isAsleep
  }

  func setupWallpaperWindows() {
    guard isSessionActive else {
      NSLog("[SESSION] 会话不活跃，跳过壁纸窗口设置")
      return
    }
    // 先清理旧窗口，添加更安全的清理机制
    print("[清理] 开始清理 \(wallpaperWindows.count) 个旧窗口...")

    for (index, window) in wallpaperWindows.enumerated() {
      print("[清理] 正在清理窗口 \(index + 1)...")

      // 清理 MTKView delegate，先暂停渲染
      if let hostingView = window.contentView as? NSHostingView<WallpaperContentView>,
        let mtkView = findMTKView(in: hostingView)
      {
        print("[清理] 暂停窗口 \(index + 1) 的渲染...")
        // 暂停渲染循环，防止在清理过程中继续绘制
        mtkView.isPaused = true

        // 等待渲染循环完全停止
        usleep(50000)  // 50ms

        // 安全停止 coordinator
        if let coordinator = mtkView.delegate as? MetalView.Coordinator {
          coordinator.safeStop()
        }

        // 再等待一段时间确保 coordinator 完全停止
        print("[清理] 等待窗口 \(index + 1) coordinator 完全停止...")
        usleep(50000)  // 50ms

        // 清理 delegate 和 device
        print("[清理] 清理窗口 \(index + 1) 的 delegate 和 device...")
        mtkView.delegate = nil
        mtkView.device = nil
      }

      print("[清理] 关闭窗口 \(index + 1)...")
      window.contentView = nil
      window.close()
    }

    wallpaperWindows.removeAll()
    metalViews.removeAll()
    print("[清理] 已清空窗口数组")

    // 更长的延迟，确保所有资源完全释放，特别是 Coordinator
    NSLog("[清理] 等待资源释放...")
    usleep(100000)  // 100ms
    NSLog("[清理] 清理完成")

    let screens = NSScreen.screens
    NSLog("[窗口] 检测到 \(screens.count) 个屏幕")

    for (index, screen) in screens.enumerated() {
      NSLog("[窗口] 正在为屏幕 \(index + 1) 设置壁纸窗口...")
      NSLog("[窗口] 屏幕 \(index + 1) 尺寸: \(screen.frame)")

      let window = WallpaperWindow(
        contentRect: screen.frame,
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered,
        defer: false,
        screen: screen
      )

      let contentView = WallpaperContentView()
      let hostingView = NSHostingView(rootView: contentView)
      window.contentView = hostingView

      window.orderFront(nil)
      window.orderBack(nil)

      wallpaperWindows.append(window)

      // 保存 MTKView 的引用以便后续截图
      if let hostingView = window.contentView as? NSHostingView<WallpaperContentView>,
        let mtkView = findMTKView(in: hostingView)
      {
        metalViews.append(mtkView)
      }

      print("屏幕 \(index + 1) 壁纸窗口已创建并显示")
      print("窗口可见: \(window.isVisible)")
    }
  }

  func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = statusItem?.button {
      button.image = NSImage(
        systemSymbolName: "sparkles", accessibilityDescription: "Shader Background")
    }

    updateMenu()
  }

  func updateMenu() {
    let menu = NSMenu()

    // 效果图库选项
    let galleryItem = NSMenuItem(
      title: "效果图库...",
      action: #selector(showEffectGallery),
      keyEquivalent: "e"
    )
    galleryItem.target = self
    menu.addItem(galleryItem)

    menu.addItem(NSMenuItem.separator())

    // 显示当前效果名称（只读，不可点击）
    let currentEffectName = EffectManager.shared.availableEffects[
      EffectManager.shared.currentEffectIndex
    ].displayName
    let currentEffectItem = NSMenuItem(
      title: "当前: \(currentEffectName)", action: nil, keyEquivalent: "")
    currentEffectItem.isEnabled = false
    menu.addItem(currentEffectItem)

    menu.addItem(NSMenuItem.separator())

    // 显示/隐藏选项
    let toggleItem = NSMenuItem(
      title: "隐藏背景",
      action: #selector(toggleWallpaper),
      keyEquivalent: "h"
    )
    toggleItem.target = self
    menu.addItem(toggleItem)

    menu.addItem(NSMenuItem.separator())

    // 退出选项
    let quitItem = NSMenuItem(
      title: "退出",
      action: #selector(quitApp),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem?.menu = menu
  }

  @objc func showEffectGallery() {
    // 如果窗口已经存在，就激活它
    if let window = galleryWindow, window.isVisible {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    // 创建 ViewModel
    let viewModel = EffectGalleryViewModel()
    viewModel.loadSavedThumbnails()
    viewModel.onEffectSelected = { [weak self] index in
      guard let self = self else { return }
      self.switchEffectByIndex(index)

      // 只有当该效果没有缩略图时才自动生成
      if viewModel.getThumbnail(for: index) == nil {
        // 使用渲染完成回调来精确触发截图
        self.setupRenderCompleteCallback(for: index)
      }
    }

    // 手动刷新缩略图的回调
    viewModel.onRefreshThumbnail = { [weak self] index in
      guard let self = self else { return }
      self.switchEffectByIndex(index)
      // 使用渲染完成回调来精确触发截图
      self.setupRenderCompleteCallback(for: index)
    }

    self.galleryViewModel = viewModel

    // 创建窗口
    let contentView = EffectGalleryView(viewModel: viewModel)
    let hostingController = NSHostingController(rootView: contentView)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1120, height: 600),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Effect Gallery"
    window.contentViewController = hostingController
    window.center()
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)

    // 激活应用
    NSApp.activate(ignoringOtherApps: true)

    self.galleryWindow = window
  }

  private func switchEffectByIndex(_ index: Int) {
    // 更新全局效果索引
    EffectManager.shared.currentEffectIndex = index

    let effectName = EffectManager.shared.availableEffects[index].displayName
    NSLog("[Gallery] 切换到效果 #\(index): \(effectName)")

    // 为所有窗口切换效果
    wallpaperWindows.forEach { window in
      guard window.isVisible else { return }

      if let hostingView = window.contentView as? NSHostingView<WallpaperContentView>,
        let mtkView = findMTKView(in: hostingView),
        let delegate = mtkView.delegate as? MetalView.Coordinator,
        mtkView.drawableSize.width > 0
      {
        NSLog("[Gallery] 为窗口切换效果到 #\(index)")
        delegate.switchToEffect(at: index, size: mtkView.drawableSize)
      }
    }

    // 更新菜单选中状态
    updateMenu()

    // 更新图库的选中状态
    galleryViewModel?.currentIndex = index
  }

  private func captureThumbnailForCurrentEffect() {
    // 简化方案：等待下一次截图完成后自动保存缩略图
    // 这样更可靠，避免直接从 Metal 纹理读取的复杂性
    NSLog("[EffectGallery] 将在下一次截图时自动保存缩略图")
  }

  @objc func switchEffect(_ sender: NSMenuItem) {
    let index = sender.tag

    // 更新全局效果索引
    EffectManager.shared.currentEffectIndex = index

    // 为所有窗口切换效果
    wallpaperWindows.forEach { window in
      guard window.isVisible else { return }

      if let hostingView = window.contentView as? NSHostingView<WallpaperContentView>,
        let mtkView = findMTKView(in: hostingView),
        let delegate = mtkView.delegate as? MetalView.Coordinator,
        mtkView.drawableSize.width > 0
      {
        delegate.switchToEffect(at: index, size: mtkView.drawableSize)
      }
    }

    // 更新菜单选中状态
    updateMenu()
  }

  // 辅助函数：在视图层级中查找 MTKView
  func findMTKView(in view: NSView) -> MTKView? {
    if let mtkView = view as? MTKView {
      return mtkView
    }
    for subview in view.subviews {
      if let found = findMTKView(in: subview) {
        return found
      }
    }
    return nil
  }

  @objc func toggleWallpaper() {
    guard !wallpaperWindows.isEmpty else { return }

    if wallpaperWindows[0].isVisible {
      wallpaperWindows.forEach { $0.orderOut(nil) }
      statusItem?.menu?.item(at: 0)?.title = "显示背景"
    } else {
      wallpaperWindows.forEach { window in
        window.orderFront(nil)
        window.orderBack(nil)
      }
      statusItem?.menu?.item(at: 0)?.title = "隐藏背景"
    }
  }

  @objc func quitApp() {
    NSApplication.shared.terminate(nil)
  }

  @objc func screenDidChange() {
    guard isSessionActive else {
      NSLog("[SESSION] 会话不活跃，忽略屏幕变化通知")
      return
    }
    print("屏幕配置已变化，重新设置壁纸窗口...")
    setupWallpaperWindows()
  }

  func setupPerformanceMonitoring() {
    PerformanceManager.shared.onPerformanceModeChanged = { [weak self] rate in
      print("性能模式已变化，更新频率: \(rate) FPS")

      // 更新所有窗口的效果更新频率
      guard let self = self else { return }

      for window in self.wallpaperWindows {
        guard window.isVisible else { continue }

        if let hostingView = window.contentView as? NSHostingView<WallpaperContentView>,
          let mtkView = self.findMTKView(in: hostingView),
          let coordinator = mtkView.delegate as? MetalView.Coordinator
        {
          coordinator.setUpdateRate(rate)
        }
      }
    }

    PerformanceManager.shared.startMonitoring()
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication, hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      wallpaperWindows.forEach { window in
        window.orderFront(nil)
        window.orderBack(nil)
      }
    }
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    // 清理定时器
    screenshotTimer?.invalidate()
    screenshotTimer = nil

    NotificationCenter.default.removeObserver(
      self,
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  @objc private func sessionDidResignActive(_ notification: Notification) {
    NSLog("[SESSION] 检测到会话锁屏，暂停壁纸更新")
    isSessionActive = false
    pendingSessionResumeWorkItem?.cancel()
    pendingSessionResumeWorkItem = nil
    stopScreenshotTimer(reason: "会话不活跃")
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.wallpaperWindows.forEach { $0.orderOut(nil) }
    }
  }

  @objc private func sessionDidBecomeActive(_ notification: Notification) {
    NSLog("[SESSION] 会话已恢复，准备恢复壁纸更新")
    isSessionActive = true
    pendingSessionResumeWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      NSLog("[SESSION] 会话恢复流程开始")
      if self.screenshotTimer == nil {
        self.setupScreenshotTimer()
      }
      self.setupWallpaperWindows()
      self.pendingSessionResumeWorkItem = nil
    }

    pendingSessionResumeWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
  }
}
