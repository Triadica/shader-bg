import Foundation
import Metal
import MetalKit

class SunWaterEffect: VisualEffect {
  var name: String = "sun_water"
  var displayName: String = "Sun & Water"
  var preferredFramesPerSecond: Int = 30
  var occludedFramesPerSecond: Int = 15

  private var renderer: SunWaterRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = SunWaterRenderer(device: device)
    renderer?.updateViewportSize(size)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    updateViewportSize(size)
  }

  func update(currentTime: Double) {
    // Time is handled in shader
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    // Optional: adjust frame rate based on update rate
  }
}
