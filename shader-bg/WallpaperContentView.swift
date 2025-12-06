//
//  WallpaperContentView.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import SwiftUI

struct WallpaperContentView: View {
  /// 显示器索引（用于多显示器场景）
  var screenIndex: Int = -1
  
  var body: some View {
    GeometryReader { geometry in
      MetalView(screenIndex: screenIndex)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .ignoresSafeArea()
    }
  }
}
