import Foundation
import Metal
import MetalKit

class MountainWavesEffect: VisualEffect {
  let name = "mountain_waves"
  let displayName = "Mountain Waves"
  let preferredFramesPerSecond = 8
  let occludedFramesPerSecond = 2

  private var renderer: MountainWavesRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = MountainWavesRenderer(device: device)
    renderer?.updateViewportSize(size)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.updateViewportSize(size)
  }

  func handleSignificantResize(to size: CGSize) {
    updateViewportSize(size)
  }

  func update(currentTime: CFTimeInterval) {}

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {}
}
