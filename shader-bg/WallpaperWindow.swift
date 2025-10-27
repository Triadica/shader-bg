//
//  WallpaperWindow.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import Cocoa

class WallpaperWindow: NSWindow {
  private var targetScreen: NSScreen?
  
  convenience init(
    contentRect: NSRect, styleMask style: NSWindow.StyleMask,
    backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool,
    screen: NSScreen
  ) {
    self.init(
      contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    self.targetScreen = screen
    self.setFrame(screen.frame, display: true)
  }
  
  override init(
    contentRect: NSRect, styleMask style: NSWindow.StyleMask,
    backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool
  ) {
    super.init(
      contentRect: contentRect, styleMask: [.borderless, .fullSizeContentView],
      backing: backingStoreType, defer: flag)

    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = false
    self.ignoresMouseEvents = true

    let desktopLevel = Int(CGWindowLevelForKey(.desktopWindow))
    self.level = NSWindow.Level(rawValue: desktopLevel + 1)

    self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

    if let screen = NSScreen.main {
      self.setFrame(screen.frame, display: true)
      self.targetScreen = screen
    }

    print("窗口层级设置为: \(self.level.rawValue)")
    print("桌面窗口层级: \(CGWindowLevelForKey(.desktopWindow))")
    print("窗口尺寸: \(self.frame)")
  }

  func updateToScreenSize() {
    if let screen = targetScreen {
      self.setFrame(screen.frame, display: true, animate: false)
    } else if let screen = NSScreen.main {
      self.setFrame(screen.frame, display: true, animate: false)
    }
  }

  override var canBecomeKey: Bool {
    return false
  }

  override var canBecomeMain: Bool {
    return false
  }
}
