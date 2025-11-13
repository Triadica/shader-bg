//
//  YearOfTruchetsEffect.swift
//  shader-bg
//
//  Created by GitHub Copilot on 2025/11/14.
//

import MetalKit

class YearOfTruchetsEffect: VisualEffect {
  var name: String { "year_of_truchets" }
  var displayName: String { "Year of Truchets" }

  private var renderer: YearOfTruchetsRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = YearOfTruchetsRenderer(device: device, size: size)
  }

  func update(currentTime: CFTimeInterval) {
    renderer?.updateParticles(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func setUpdateRate(_ rate: Double) {
    renderer?.updateInterval = 1.0 / rate
  }
}
