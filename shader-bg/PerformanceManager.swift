//
//  PerformanceManager.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Cocoa
import Foundation

// 性能管理器 - 根据桌面可见性动态调整更新频率
class PerformanceManager {
  static let shared = PerformanceManager()

  // 更新频率（每秒帧数）
  private(set) var currentUpdateRate: Double = 15.0  // 默认每秒 15 次
  let highPerformanceRate: Double = 30.0  // 高性能：每秒 30 次
  let lowPerformanceRate: Double = 10.0  // 低性能：每秒 10 次

  private(set) var isDesktopVisible: Bool = true
  private var checkTimer: Timer?

  var onPerformanceModeChanged: ((Double) -> Void)?

  private init() {
    startMonitoring()
  }

  func startMonitoring() {
    // 每 2 秒检测一次桌面可见性
    checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      self?.checkDesktopVisibility()
    }

    // 立即检测一次
    checkDesktopVisibility()

    // 监听应用激活/停用事件
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(workspaceDidActivate),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )
  }

  @objc private func workspaceDidActivate(_ notification: Notification) {
    // 当有应用激活时，延迟检测桌面可见性
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.checkDesktopVisibility()
    }
  }

  private func checkDesktopVisibility() {
    let wasVisible = isDesktopVisible
    isDesktopVisible = isDesktopCurrentlyVisible()

    // 如果状态改变，更新性能模式
    if wasVisible != isDesktopVisible {
      updatePerformanceMode()
    }
  }

  private func isDesktopCurrentlyVisible() -> Bool {
    // 方法1: 检查是否有全屏或大窗口覆盖桌面
    let screens = NSScreen.screens

    // 获取所有窗口信息
    let windowList =
      CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [[String: Any]]

    guard let windows = windowList else { return true }

    // 检查是否有大型窗口遮挡桌面
    var hasMajorOcclusion = false

    for window in windows {
      // 跳过我们自己的应用
      if let ownerName = window[kCGWindowOwnerName as String] as? String,
        ownerName.contains("shader-bg")
      {
        continue
      }

      // 检查窗口层级（桌面层以上）
      if let level = window[kCGWindowLayer as String] as? Int,
        level <= 0
      {
        continue  // 跳过桌面层及以下的窗口
      }

      // 获取窗口边界
      if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
        let x = bounds["X"],
        let y = bounds["Y"],
        let width = bounds["Width"],
        let height = bounds["Height"]
      {

        let windowRect = CGRect(x: x, y: y, width: width, height: height)

        // 检查是否是大窗口（占据屏幕面积超过 40%）
        for screen in screens {
          let screenRect = screen.frame
          let intersection = windowRect.intersection(screenRect)
          let screenArea = screenRect.width * screenRect.height
          let intersectionArea = intersection.width * intersection.height

          if intersectionArea > screenArea * 0.4 {
            hasMajorOcclusion = true
            break
          }
        }

        if hasMajorOcclusion {
          break
        }
      }
    }

    // 方法2: 检查是否在"显示桌面"模式（Mission Control 或 F11）
    // 如果没有主要遮挡，认为桌面可见
    return !hasMajorOcclusion
  }

  private func updatePerformanceMode() {
    let newRate = isDesktopVisible ? highPerformanceRate : lowPerformanceRate

    if newRate != currentUpdateRate {
      currentUpdateRate = newRate
      print("性能模式切换: \(isDesktopVisible ? "高性能" : "低性能") - 更新频率: \(currentUpdateRate) FPS")

      // 通知观察者性能模式已改变，传递新的更新频率
      onPerformanceModeChanged?(currentUpdateRate)
    }
  }

  func stopMonitoring() {
    checkTimer?.invalidate()
    checkTimer = nil
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  deinit {
    stopMonitoring()
  }
}
