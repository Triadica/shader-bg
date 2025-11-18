import simd

struct Tesseract4DData {
  var time: Float
  var resolution: SIMD2<Float>
  var padding: SIMD2<Float> = SIMD2<Float>(0, 0)
}
