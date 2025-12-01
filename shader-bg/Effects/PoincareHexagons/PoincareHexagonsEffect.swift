import MetalKit

class PoincareHexagonsEffect: VisualEffect {
  var name: String = "PoincareHexagons"
  var displayName: String { "Poincare Hexagons" }
  var renderer: PoincareHexagonsRenderer?

  func setup(device: MTLDevice, size: CGSize) {
    renderer = PoincareHexagonsRenderer(device: device, pixelFormat: .bgra8Unorm)
  }

  func updateViewportSize(_ size: CGSize) {
    renderer?.params.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
  }

  func update(currentTime: CFTimeInterval) {
    renderer?.updateParticles()
  }

  func draw(in view: MTKView) {
    renderer?.draw(in: view)
  }

  func setUpdateRate(_ rate: Double) {
    // Optional: adjust animation speed based on rate if needed
  }
}
