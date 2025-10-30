//
//  AppDelegate.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Cocoa
import MetalKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  var wallpaperWindows: [WallpaperWindow] = []
  var statusItem: NSStatusItem?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    setupWallpaperWindows()
    setupMenuBar()
    setupPerformanceMonitoring()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
  }

  func setupWallpaperWindows() {
    // 先清理旧窗口
    wallpaperWindows.forEach { window in
      // 清理 MTKView delegate
      if let hostingView = window.contentView as? NSHostingView<WallpaperContentView>,
        let mtkView = findMTKView(in: hostingView)
      {
        mtkView.delegate = nil
        mtkView.device = nil
      }
      window.contentView = nil
      window.close()
    }
    wallpaperWindows.removeAll()

    let screens = NSScreen.screens
    print("检测到 \(screens.count) 个屏幕")

    for (index, screen) in screens.enumerated() {
      print("正在为屏幕 \(index + 1) 设置壁纸窗口...")
      print("屏幕 \(index + 1) 尺寸: \(screen.frame)")

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

      window.makeKeyAndOrderFront(nil)
      window.orderBack(nil)

      wallpaperWindows.append(window)

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

    // 效果选择项（展开到第一层菜单）
    let effectManager = EffectManager.shared
    
    for (index, effect) in effectManager.availableEffects.enumerated() {
      let effectItem = NSMenuItem(
        title: effect.displayName,
        action: #selector(switchEffect(_:)),
        keyEquivalent: ""
      )
      effectItem.target = self
      effectItem.tag = index
      effectItem.state = index == effectManager.currentEffectIndex ? .on : .off
      menu.addItem(effectItem)
    }

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
        window.makeKeyAndOrderFront(nil)
        window.orderBack(nil)
      }
      statusItem?.menu?.item(at: 0)?.title = "隐藏背景"
    }
  }

  @objc func quitApp() {
    NSApplication.shared.terminate(nil)
  }

  @objc func screenDidChange() {
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
        window.makeKeyAndOrderFront(nil)
        window.orderBack(nil)
      }
    }
    return true
  }
}
