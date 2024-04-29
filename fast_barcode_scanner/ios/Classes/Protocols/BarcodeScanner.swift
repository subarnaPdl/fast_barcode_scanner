import AVFoundation
import Flutter

protocol BarcodeScanner {

  /// Either a serialized list of barcodes or a `FlutterError`
  /// Serialization format: [type, value, valueType, minX, minY, maxX, maxY]
  typealias ResultHandler = (Any?) -> Void

  var session: AVCaptureSession? { get set }

  var symbologies: [String] { get set }

  var onDetection: (() -> Void)? { get set }

  func start()

  func stop()
}
