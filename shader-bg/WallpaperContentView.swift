//
//  WallpaperContentView.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import SwiftUI

struct WallpaperContentView: View {
  var body: some View {
    GeometryReader { geometry in
      MetalView()
        .frame(width: geometry.size.width, height: geometry.size.height)
        .ignoresSafeArea()
    }
  }
}
