//
//  ContentView.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    MetalView()
      .frame(minWidth: 800, minHeight: 600)
      .ignoresSafeArea()
  }
}

#Preview {
  ContentView()
}
