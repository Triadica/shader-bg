//
//  CityOfKaliEffect.swift
//  shader-bg
//
//  Created on 2025-11-03.
//

import Metal
import MetalKit

class CityOfKaliEffect: VisualEffect {
  var name: String = "city_of_kali"
  var displayName: String = "City of Kali"

  private var renderer: CityOfKaliRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = CityOfKaliRenderer(device: device, size: size)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.viewportSize = size
  }

  func update(currentTime: CFTimeInterval) {
    renderer?.updateParticles(currentTime: currentTime)
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    renderer?.updateInterval = rate
  }
}
