//
//  PerformanceManager.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Cocoa
import Foundation
import IOKit.ps

// 性能管理器 - 根据桌面可见性动态调整更新频率
class PerformanceManager {
  static let shared = PerformanceManager()

  // 更新频率（每秒帧数）
  private(set) var currentUpdateRate: Double = 15.0  // 默认每秒 15 次
  let highPerformanceRate: Double = 30.0  // 高性能：每秒 30 次
  let lowPerformanceRate: Double = 10.0  // 低性能：每秒 10 次

  private(set) var isDesktopVisible: Bool = true
  private var checkTimer: Timer?
  private var resourceCheckTimer: Timer?

  // CPU 和 GPU 监控
  private var lastCPUUsage: Double = 0.0
  private var lastGPUUsage: Double = 0.0
  private var hasLoggedHighCPU: Bool = false
  private var hasLoggedHighGPU: Bool = false
  private let cpuThreshold: Double = 40.0  // CPU 使用率阈值
  private let gpuThreshold: Double = 40.0  // GPU 使用率阈值

  var onPerformanceModeChanged: ((Double) -> Void)?

  private init() {
    startMonitoring()
  }

  func startMonitoring() {
    // 每 2 秒检测一次桌面可见性
    checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      self?.checkDesktopVisibility()
    }

    // 每 5 秒检测一次 CPU 和 GPU 占用
    resourceCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) {
      [weak self] _ in
      self?.checkResourceUsage()
    }

    // 立即检测一次
    checkDesktopVisibility()
    checkResourceUsage()

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

  // MARK: - CPU 和 GPU 监控

  private func checkResourceUsage() {
    let cpuUsage = getCPUUsage()
    let gpuUsage = getGPUUsage()

    lastCPUUsage = cpuUsage
    lastGPUUsage = gpuUsage

    // 检查 CPU 占用
    if cpuUsage > cpuThreshold {
      if !hasLoggedHighCPU {
        hasLoggedHighCPU = true
        NSLog("[性能监控] ⚠️ CPU 占用率较高: %.1f%% (阈值: %.0f%%)", cpuUsage, cpuThreshold)
      }
    } else {
      hasLoggedHighCPU = false
    }

    // 检查 GPU 占用
    if gpuUsage > gpuThreshold {
      if !hasLoggedHighGPU {
        hasLoggedHighGPU = true
        NSLog("[性能监控] ⚠️ GPU 占用率较高: %.1f%% (阈值: %.0f%%)", gpuUsage, gpuThreshold)
      }
    } else {
      hasLoggedHighGPU = false
    }
  }

  private func getCPUUsage() -> Double {
    var totalUsageOfCPU: Double = 0.0
    var threadsList: thread_act_array_t?
    var threadsCount = mach_msg_type_number_t(0)
    let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
      $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
        task_threads(mach_task_self_, $0, &threadsCount)
      }
    }

    if threadsResult == KERN_SUCCESS, let threadsList = threadsList {
      for index in 0..<threadsCount {
        var threadInfo = thread_basic_info()
        var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
        let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
          $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            thread_info(
              threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
          }
        }

        guard infoResult == KERN_SUCCESS else {
          break
        }

        let threadBasicInfo = threadInfo as thread_basic_info
        if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
          totalUsageOfCPU += (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
        }
      }

      vm_deallocate(
        mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)),
        vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
    }

    return totalUsageOfCPU
  }

  private func getGPUUsage() -> Double {
    // Metal GPU 占用率检测
    // 注意：精确的 GPU 占用率需要使用 IOKit 或其他系统 API
    // 这里提供一个简化版本，基于系统电源状态

    // 尝试通过 IOKit 获取 GPU 信息
    let matching = IOServiceMatching("IOAccelerator")
    var iterator: io_iterator_t = 0

    let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
    guard result == KERN_SUCCESS else {
      return 0.0
    }

    defer {
      IOObjectRelease(iterator)
    }

    var gpuUsage: Double = 0.0
    var service = IOIteratorNext(iterator)

    while service != 0 {
      defer {
        IOObjectRelease(service)
        service = IOIteratorNext(iterator)
      }

      // 尝试获取 GPU 性能状态
      var props: Unmanaged<CFMutableDictionary>?
      let propsResult = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)

      if propsResult == KERN_SUCCESS, let properties = props?.takeRetainedValue() as? [String: Any]
      {
        // 查找 GPU 利用率相关属性
        if let perfStats = properties["PerformanceStatistics"] as? [String: Any] {
          if let deviceUtil = perfStats["Device Utilization %"] as? Double {
            gpuUsage = max(gpuUsage, deviceUtil)
          } else if let util = perfStats["Utilization %"] as? Double {
            gpuUsage = max(gpuUsage, util)
          }
        }
      }
    }

    return gpuUsage
  }

  func stopMonitoring() {
    checkTimer?.invalidate()
    checkTimer = nil
    resourceCheckTimer?.invalidate()
    resourceCheckTimer = nil
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  deinit {
    stopMonitoring()
  }
}
