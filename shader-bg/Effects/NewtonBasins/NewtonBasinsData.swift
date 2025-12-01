import Foundation
import simd

struct NewtonBasinsData {
  var time: Float = 0.0
  var resolution: SIMD2<Float> = SIMD2<Float>(0, 0)
  var mouse: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0)
  var padding: Float = 0.0
}
