//
//  shader_bgApp.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import SwiftUI

@main
struct shaderBgApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    // 保留一个空的 WindowGroup 以满足 App 协议要求
    // 实际的壁纸窗口由 AppDelegate 管理
    Settings {
      EmptyView()
    }
  }
}
