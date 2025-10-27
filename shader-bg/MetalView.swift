//
//  MetalView.swift
//  shader-bg
//
//  Created by chen on 2025/10/28.
//

import MetalKit
import SwiftUI

struct MetalView: NSViewRepresentable {
  func makeNSView(context: Context) -> MTKView {
    let mtkView = MTKView()
    mtkView.device = MTLCreateSystemDefaultDevice()
    mtkView.delegate = context.coordinator
    mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
    mtkView.preferredFramesPerSecond = 60
    mtkView.enableSetNeedsDisplay = false
    mtkView.isPaused = false

    // 启用混合以支持透明度
    mtkView.framebufferOnly = false

    return mtkView
  }

  func updateNSView(_ nsView: MTKView, context: Context) {
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, MTKViewDelegate {
    var parent: MetalView
    var renderer: Renderer?

    init(_ parent: MetalView) {
      self.parent = parent
      super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
      renderer?.updateViewportSize(size)
    }

    func draw(in view: MTKView) {
      if renderer == nil {
        renderer = Renderer(device: view.device!, size: view.drawableSize)
      }
      renderer?.draw(in: view)
    }
  }
}
