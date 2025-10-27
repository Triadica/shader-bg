//
//  AppDelegate.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  var wallpaperWindows: [WallpaperWindow] = []
  var statusItem: NSStatusItem?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    setupWallpaperWindows()
    setupMenuBar()
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
  }

  func setupWallpaperWindows() {
    wallpaperWindows.forEach { $0.close() }
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

    let menu = NSMenu()

    let toggleItem = NSMenuItem(
      title: "隐藏背景",
      action: #selector(toggleWallpaper),
      keyEquivalent: "h"
    )
    toggleItem.target = self
    menu.addItem(toggleItem)

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(
      title: "退出",
      action: #selector(quitApp),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem?.menu = menu
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
