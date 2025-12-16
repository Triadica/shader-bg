//
//  InputEventManager.swift
//  shader-bg
//
//  Created by chen on 2025/12/05.
//

import Cocoa
import simd

/// 输入事件管理器 - 监听全局鼠标和键盘事件
/// 当鼠标或键盘在桌面上（而非其他窗口）时，捕获这些事件用于 shader 渲染
class InputEventManager {
  static let shared = InputEventManager()

  // MARK: - 输入状态

  /// 是否有鼠标活动（鼠标在桌面上移动）
  private(set) var hasMouseActivity: Bool = false

  /// 当前鼠标位置（归一化到 0-1）
  private(set) var mousePosition: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)

  /// 当前鼠标所在的显示器索引（-1 表示未知）
  private(set) var currentScreenIndex: Int = -1

  /// 键盘按键位置数组（最多4个点，归一化到 0-1）
  private(set) var keyPositions: [SIMD2<Float>] = []

  /// 涟漪事件队列（鼠标点击或键盘按下产生的涟漪）
  private(set) var rippleEvents: [RippleEvent] = []

  /// 最大涟漪事件数量
  private let maxRippleEvents = 8

  /// 鼠标位置历史（用于绘制轨迹）
  private(set) var mouseTrail: [SIMD2<Float>] = []
  private let maxTrailLength = 32

  // MARK: - 事件监听器

  private var mouseMovedMonitor: Any?
  private var mouseClickMonitor: Any?
  private var keyDownMonitor: Any?
  private var keyUpMonitor: Any?

  /// 当前按下的键
  private var pressedKeys: Set<UInt16> = []

  /// 鼠标活动超时计时器
  private var mouseActivityTimer: Timer?
  private let mouseActivityTimeout: TimeInterval = 2.0

  // MARK: - 屏幕尺寸（用于坐标归一化）

  private var screenSize: CGSize = CGSize(width: 1920, height: 1080)

  private init() {
    updateScreenSize()
  }

  /// 开始监听输入事件
  func startListening() {
    NSLog("[InputEventManager] 开始监听输入事件")

    updateScreenSize()

    // 监听鼠标移动（全局）
    mouseMovedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) {
      [weak self] event in
      self?.handleMouseMoved(event)
    }

    // 监听鼠标点击（全局）
    mouseClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
      .leftMouseDown, .rightMouseDown,
    ]) { [weak self] event in
      self?.handleMouseClick(event)
    }

    // 监听键盘按下（全局）
    keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.handleKeyDown(event)
    }

    // 监听键盘释放（全局）
    keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
      self?.handleKeyUp(event)
    }

    NSLog("[InputEventManager] 事件监听器已设置")
  }

  /// 停止监听输入事件
  func stopListening() {
    NSLog("[InputEventManager] 停止监听输入事件")

    if let monitor = mouseMovedMonitor {
      NSEvent.removeMonitor(monitor)
      mouseMovedMonitor = nil
    }

    if let monitor = mouseClickMonitor {
      NSEvent.removeMonitor(monitor)
      mouseClickMonitor = nil
    }

    if let monitor = keyDownMonitor {
      NSEvent.removeMonitor(monitor)
      keyDownMonitor = nil
    }

    if let monitor = keyUpMonitor {
      NSEvent.removeMonitor(monitor)
      keyUpMonitor = nil
    }

    mouseActivityTimer?.invalidate()
    mouseActivityTimer = nil
  }

  /// 更新屏幕尺寸
  func updateScreenSize() {
    if let screen = NSScreen.main {
      screenSize = screen.frame.size
      NSLog("[InputEventManager] 屏幕尺寸更新: \(screenSize)")
    }
  }

  /// 获取鼠标所在的显示器索引
  private func getScreenIndex(for location: NSPoint) -> Int {
    let screens = NSScreen.screens
    for (index, screen) in screens.enumerated() {
      if screen.frame.contains(location) {
        return index
      }
    }
    return -1
  }

  /// 检查指定位置是否在桌面上（没有其他窗口覆盖）
  /// 通过 CGWindowListCopyWindowInfo 获取所有窗口，检查点击位置是否被其他窗口覆盖
  private func isOnDesktop(location: NSPoint) -> Bool {
    // 获取所有可见窗口（从前到后排序）
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
    else {
      NSLog("[InputEventManager] 无法获取窗口列表，默认认为在桌面上")
      return true
    }

    // macOS 的 CGWindow 坐标系原点在左上角，而 NSEvent.mouseLocation 原点在左下角
    // 需要转换坐标
    let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 1080
    let cgLocation = CGPoint(x: location.x, y: primaryScreenHeight - location.y)

    for windowInfo in windowList {
      // 获取窗口所有者名称
      let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? ""

      // 跳过自己的应用窗口
      if ownerName == "shader-bg" {
        continue
      }

      // 跳过某些系统进程
      let skipProcesses = [
        "Window Server", "Dock", "SystemUIServer", "Control Center", "Notification Center",
      ]
      if skipProcesses.contains(ownerName) {
        continue
      }

      // 跳过 Dock 和菜单栏等系统元素 (layer 不在正常窗口范围)
      if let layer = windowInfo[kCGWindowLayer as String] as? Int32 {
        // 正常窗口的 layer 通常是 0，菜单栏是 25，其他系统 UI 可能更高或负数
        if layer != 0 {
          continue
        }
      }

      // 获取窗口边界
      if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] {
        let windowFrame = CGRect(
          x: boundsDict["X"] ?? 0,
          y: boundsDict["Y"] ?? 0,
          width: boundsDict["Width"] ?? 0,
          height: boundsDict["Height"] ?? 0
        )

        // 检查点击位置是否在这个窗口内
        if windowFrame.contains(cgLocation) {
          NSLog("[InputEventManager] 点击被窗口遮挡: \(ownerName)")
          return false
        }
      }
    }

    // 没有其他窗口覆盖，是桌面
    NSLog("[InputEventManager] 点击在桌面上")
    return true
  }

  /// 获取指定显示器的归一化坐标
  private func normalizePosition(location: NSPoint, screenIndex: Int) -> SIMD2<Float>? {
    let screens = NSScreen.screens
    guard screenIndex >= 0 && screenIndex < screens.count else { return nil }

    let screenFrame = screens[screenIndex].frame
    let normalizedX = Float((location.x - screenFrame.origin.x) / screenFrame.width)
    let normalizedY = Float((location.y - screenFrame.origin.y) / screenFrame.height)

    return SIMD2<Float>(
      max(0, min(1, normalizedX)),
      max(0, min(1, normalizedY))
    )
  }

  // MARK: - 事件处理

  private func handleMouseMoved(_ event: NSEvent) {
    // 获取鼠标在屏幕上的位置（macOS 坐标系：原点在左下角）
    let location = NSEvent.mouseLocation

    // 注意：鼠标移动不做桌面检测，因为 CGWindowListCopyWindowInfo 调用开销大
    // 只在点击时检测是否在桌面上

    // 确定鼠标在哪个显示器上
    currentScreenIndex = getScreenIndex(for: location)

    // 归一化坐标（相对于当前显示器）
    if let normalized = normalizePosition(location: location, screenIndex: currentScreenIndex) {
      mousePosition = normalized
    }

    hasMouseActivity = true

    // 添加到轨迹
    mouseTrail.append(mousePosition)
    if mouseTrail.count > maxTrailLength {
      mouseTrail.removeFirst()
    }

    // 重置鼠标活动超时
    resetMouseActivityTimer()
  }

  private func handleMouseClick(_ event: NSEvent) {
    let location = NSEvent.mouseLocation

    // 检查点击是否在桌面上（没有其他窗口覆盖）
    guard isOnDesktop(location: location) else {
      NSLog("[InputEventManager] 点击不在桌面上，忽略")
      return
    }

    // 确定点击在哪个显示器上
    let screenIndex = getScreenIndex(for: location)

    // 归一化坐标
    guard let normalized = normalizePosition(location: location, screenIndex: screenIndex) else {
      NSLog("[InputEventManager] 无法归一化坐标")
      return
    }

    // 创建涟漪事件，带上显示器索引
    let ripple = RippleEvent(
      position: normalized,
      startTime: CACurrentMediaTime(),
      strength: event.type == .leftMouseDown ? 1.0 : 0.7,
      screenIndex: screenIndex
    )

    addRippleEvent(ripple)
    NSLog(
      "[InputEventManager] 鼠标点击产生涟漪: (\(normalized.x), \(normalized.y)) 显示器: \(screenIndex), 当前涟漪总数: \(rippleEvents.count)"
    )
  }

  private func handleKeyDown(_ event: NSEvent) {
    let keyCode = event.keyCode

    // 避免重复按键
    guard !pressedKeys.contains(keyCode) else { return }
    pressedKeys.insert(keyCode)

    // 根据键盘位置计算坐标
    let position = keyCodeToPosition(keyCode)

    // 更新按键位置数组（最多4个）
    if keyPositions.count < 4 {
      keyPositions.append(position)
    } else {
      // 替换最旧的
      keyPositions.removeFirst()
      keyPositions.append(position)
    }

    // 键盘事件使用当前鼠标所在的显示器
    let ripple = RippleEvent(
      position: position,
      startTime: CACurrentMediaTime(),
      strength: 0.8,
      screenIndex: currentScreenIndex
    )

    addRippleEvent(ripple)
    NSLog("[InputEventManager] 键盘按下产生涟漪: keyCode=\(keyCode), 显示器: \(currentScreenIndex)")
  }

  private func handleKeyUp(_ event: NSEvent) {
    let keyCode = event.keyCode
    pressedKeys.remove(keyCode)

    // 从按键位置数组中移除
    let position = keyCodeToPosition(keyCode)
    keyPositions.removeAll { abs($0.x - position.x) < 0.01 && abs($0.y - position.y) < 0.01 }
  }

  /// 将键盘按键码转换为屏幕位置（基于键盘物理布局）
  private func keyCodeToPosition(_ keyCode: UInt16) -> SIMD2<Float> {
    // 键盘大致布局映射
    // 将键盘分成一个网格，根据按键位置返回归一化坐标

    // 行信息 (row: 0=数字行, 1=QWERTY, 2=ASDF, 3=ZXCV, 4=空格行)
    // 列信息 (大约 0-14 列)

    var row: Float = 0.5
    var col: Float = 0.5

    switch keyCode {
    // 数字行 (row 0)
    case 50:
      row = 0.0
      col = 0.0  // `
    case 18:
      row = 0.0
      col = 1.0  // 1
    case 19:
      row = 0.0
      col = 2.0  // 2
    case 20:
      row = 0.0
      col = 3.0  // 3
    case 21:
      row = 0.0
      col = 4.0  // 4
    case 23:
      row = 0.0
      col = 5.0  // 5
    case 22:
      row = 0.0
      col = 6.0  // 6
    case 26:
      row = 0.0
      col = 7.0  // 7
    case 28:
      row = 0.0
      col = 8.0  // 8
    case 25:
      row = 0.0
      col = 9.0  // 9
    case 29:
      row = 0.0
      col = 10.0  // 0
    case 27:
      row = 0.0
      col = 11.0  // -
    case 24:
      row = 0.0
      col = 12.0  // =

    // QWERTY 行 (row 1)
    case 12:
      row = 1.0
      col = 0.5  // Q
    case 13:
      row = 1.0
      col = 1.5  // W
    case 14:
      row = 1.0
      col = 2.5  // E
    case 15:
      row = 1.0
      col = 3.5  // R
    case 17:
      row = 1.0
      col = 4.5  // T
    case 16:
      row = 1.0
      col = 5.5  // Y
    case 32:
      row = 1.0
      col = 6.5  // U
    case 34:
      row = 1.0
      col = 7.5  // I
    case 31:
      row = 1.0
      col = 8.5  // O
    case 35:
      row = 1.0
      col = 9.5  // P
    case 33:
      row = 1.0
      col = 10.5  // [
    case 30:
      row = 1.0
      col = 11.5  // ]

    // ASDF 行 (row 2)
    case 0:
      row = 2.0
      col = 0.75  // A
    case 1:
      row = 2.0
      col = 1.75  // S
    case 2:
      row = 2.0
      col = 2.75  // D
    case 3:
      row = 2.0
      col = 3.75  // F
    case 5:
      row = 2.0
      col = 4.75  // G
    case 4:
      row = 2.0
      col = 5.75  // H
    case 38:
      row = 2.0
      col = 6.75  // J
    case 40:
      row = 2.0
      col = 7.75  // K
    case 37:
      row = 2.0
      col = 8.75  // L
    case 41:
      row = 2.0
      col = 9.75  // ;
    case 39:
      row = 2.0
      col = 10.75  // '

    // ZXCV 行 (row 3)
    case 6:
      row = 3.0
      col = 1.25  // Z
    case 7:
      row = 3.0
      col = 2.25  // X
    case 8:
      row = 3.0
      col = 3.25  // C
    case 9:
      row = 3.0
      col = 4.25  // V
    case 11:
      row = 3.0
      col = 5.25  // B
    case 45:
      row = 3.0
      col = 6.25  // N
    case 46:
      row = 3.0
      col = 7.25  // M
    case 43:
      row = 3.0
      col = 8.25  // ,
    case 47:
      row = 3.0
      col = 9.25  // .
    case 44:
      row = 3.0
      col = 10.25  // /

    // 空格行 (row 4)
    case 49:
      row = 4.0
      col = 5.5  // Space

    // 方向键
    case 123:
      row = 4.5
      col = 12.0  // Left
    case 124:
      row = 4.5
      col = 14.0  // Right
    case 126:
      row = 3.5
      col = 13.0  // Up
    case 125:
      row = 4.5
      col = 13.0  // Down

    default:
      // 未知按键，使用随机位置
      row = Float.random(in: 0...4)
      col = Float.random(in: 0...12)
    }

    // 归一化到 0-1 范围
    let normalizedX = (col + 0.5) / 14.0
    let normalizedY = 1.0 - (row + 0.5) / 5.0  // Y 翻转，让数字行在顶部

    return SIMD2<Float>(normalizedX, normalizedY)
  }

  private func addRippleEvent(_ event: RippleEvent) {
    rippleEvents.append(event)
    if rippleEvents.count > maxRippleEvents {
      rippleEvents.removeFirst()
    }
  }

  private func resetMouseActivityTimer() {
    mouseActivityTimer?.invalidate()
    mouseActivityTimer = Timer.scheduledTimer(
      withTimeInterval: mouseActivityTimeout, repeats: false
    ) { [weak self] _ in
      self?.hasMouseActivity = false
      self?.mouseTrail.removeAll()
    }
  }

  /// 清理过期的涟漪事件（延长到8秒让涟漪持续更久）
  func cleanupExpiredRipples(maxAge: TimeInterval = 8.0) {
    let currentTime = CACurrentMediaTime()
    rippleEvents.removeAll { currentTime - $0.startTime > maxAge }
  }

  /// 获取当前输入状态用于 shader（所有显示器）
  func getInputState() -> InputState {
    return getInputState(forScreen: nil)
  }

  /// 获取指定显示器的输入状态
  /// - Parameter screenIndex: 显示器索引，nil 表示所有显示器
  func getInputState(forScreen screenIndex: Int?) -> InputState {
    cleanupExpiredRipples()

    // 过滤涟漪事件
    // 如果 screenIndex 是 nil 或 -1，返回所有涟漪
    let filteredRipples: [RippleEvent]
    if let screenIndex = screenIndex, screenIndex >= 0 {
      filteredRipples = rippleEvents.filter { $0.screenIndex == screenIndex }
    } else {
      filteredRipples = rippleEvents
    }

    // 判断鼠标是否在指定显示器上
    let mouseActive: Bool
    let mousePos: SIMD2<Float>
    if let screenIndex = screenIndex, screenIndex >= 0 {
      mouseActive = hasMouseActivity && currentScreenIndex == screenIndex
      mousePos = mouseActive ? mousePosition : SIMD2<Float>(0.5, 0.5)
    } else {
      mouseActive = hasMouseActivity
      mousePos = mousePosition
    }

    return InputState(
      hasMouseActivity: mouseActive,
      mousePosition: mousePos,
      keyPositions: keyPositions,
      rippleEvents: filteredRipples,
      mouseTrail: mouseActive ? mouseTrail : [],
      screenIndex: screenIndex ?? -1
    )
  }
}

// MARK: - 数据结构

/// 涟漪事件
struct RippleEvent {
  let position: SIMD2<Float>
  let startTime: CFTimeInterval
  let strength: Float
  let screenIndex: Int  // 所属显示器索引

  init(position: SIMD2<Float>, startTime: CFTimeInterval, strength: Float, screenIndex: Int = -1) {
    self.position = position
    self.startTime = startTime
    self.strength = strength
    self.screenIndex = screenIndex
  }
}

/// 输入状态（用于传递给 shader）
struct InputState {
  let hasMouseActivity: Bool
  let mousePosition: SIMD2<Float>
  let keyPositions: [SIMD2<Float>]
  let rippleEvents: [RippleEvent]
  let mouseTrail: [SIMD2<Float>]
  let screenIndex: Int  // 当前状态对应的显示器

  init(
    hasMouseActivity: Bool, mousePosition: SIMD2<Float>, keyPositions: [SIMD2<Float>],
    rippleEvents: [RippleEvent], mouseTrail: [SIMD2<Float>], screenIndex: Int = -1
  ) {
    self.hasMouseActivity = hasMouseActivity
    self.mousePosition = mousePosition
    self.keyPositions = keyPositions
    self.rippleEvents = rippleEvents
    self.mouseTrail = mouseTrail
    self.screenIndex = screenIndex
  }
}

/// Shader 使用的输入数据结构（需要与 Metal shader 保持一致）
struct ShaderInputData {
  var hasMouseActivity: Int32  // Bool 用 Int32 表示
  var mousePosition: SIMD2<Float>
  var rippleCount: Int32
  var ripples:
    (
      SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
      SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>
    )  // 最多8个涟漪：(x, y, age, strength)

  init(from inputState: InputState, currentTime: CFTimeInterval) {
    self.hasMouseActivity = inputState.hasMouseActivity ? 1 : 0
    self.mousePosition = inputState.mousePosition
    self.rippleCount = Int32(min(inputState.rippleEvents.count, 8))

    // 初始化涟漪数据
    var r0 = SIMD4<Float>(0, 0, 0, 0)
    var r1 = SIMD4<Float>(0, 0, 0, 0)
    var r2 = SIMD4<Float>(0, 0, 0, 0)
    var r3 = SIMD4<Float>(0, 0, 0, 0)
    var r4 = SIMD4<Float>(0, 0, 0, 0)
    var r5 = SIMD4<Float>(0, 0, 0, 0)
    var r6 = SIMD4<Float>(0, 0, 0, 0)
    var r7 = SIMD4<Float>(0, 0, 0, 0)

    for (index, ripple) in inputState.rippleEvents.prefix(8).enumerated() {
      let age = Float(currentTime - ripple.startTime)
      let data = SIMD4<Float>(ripple.position.x, ripple.position.y, age, ripple.strength)

      switch index {
      case 0: r0 = data
      case 1: r1 = data
      case 2: r2 = data
      case 3: r3 = data
      case 4: r4 = data
      case 5: r5 = data
      case 6: r6 = data
      case 7: r7 = data
      default: break
      }
    }

    self.ripples = (r0, r1, r2, r3, r4, r5, r6, r7)
  }
}
