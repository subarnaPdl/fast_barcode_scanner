import AVFoundation
import Flutter
import Vision

typealias VisionBarcodeCornerPointConverter = (VNBarcodeObservation) -> CGRect?

class VisionBarcodeScanner: NSObject, BarcodeScanner, AVCaptureVideoDataOutputSampleBufferDelegate {
  var resultHandler: ResultHandler
  var cornerPointConverter: VisionBarcodeCornerPointConverter?
  var confidence: Float
  var onDetection: (() -> Void)?

  private let output = AVCaptureVideoDataOutput()
  private let outputQueue = DispatchQueue(
    label: "fast_barcode_scanner.data.serial", qos: .userInitiated,
    attributes: [], autoreleaseFrequency: .workItem)

  private let visionSequenceHandler = VNSequenceRequestHandler()
  private lazy var visionBarcodesRequests: [VNDetectBarcodesRequest]! = {
    let request = VNDetectBarcodesRequest(completionHandler: handleVisionRequestUpdate)

    if #available(iOS 17, *) {
      request.revision = VNDetectBarcodesRequestRevision4
    } else if #available(iOS 16, *) {
      request.revision = VNDetectBarcodesRequestRevision3
    } else if #available(iOS 15, *) {
      request.revision = VNDetectBarcodesRequestRevision2
    }

    return [request]
  }()

  private var _symbologies = [String]()
  var symbologies: [String] {
    get {
      _symbologies
    }
    set {
      _symbologies = newValue

      // This will just ignore all unsupported types
      visionBarcodesRequests.first!.symbologies = newValue.compactMap({ vnBarcodeSymbols[$0] })

      // UPC-A is reported as EAN-13
      if newValue.contains("upcA") && !visionBarcodesRequests.first!.symbologies.contains(.EAN13) {
        visionBarcodesRequests.first!.symbologies.append(.EAN13)
      }

      // Report to the user if any types are not supported
      if visionBarcodesRequests.first!.symbologies.count != newValue.count {
        let unsupportedTypes = newValue.filter {
          vnBarcodeSymbols[$0] == nil
        }

        print("WARNING: Unsupported barcode types selected: \(unsupportedTypes)")
      }
    }
  }

  private var _session: AVCaptureSession?
  var session: AVCaptureSession? {
    get {
      _session
    }
    set {
      _session = newValue
      if let session = newValue, session.canAddOutput(output), !session.outputs.contains(output) {
        session.addOutput(output)
      }
    }
  }

  init(
    confidence: Float, cornerPointConverter: VisionBarcodeCornerPointConverter? = nil,
    resultHandler: @escaping ResultHandler
  ) {
    self.cornerPointConverter = cornerPointConverter
    self.confidence = confidence
    self.resultHandler = resultHandler

    super.init()

    output.alwaysDiscardsLateVideoFrames = true
  }

  func start() {
    output.setSampleBufferDelegate(self, queue: outputQueue)
  }

  func stop() {
    output.setSampleBufferDelegate(nil, queue: nil)
  }

  // MARK: Vision capture output

  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
      do {
        try visionSequenceHandler.perform(visionBarcodesRequests, on: pixelBuffer)
      } catch {
        handleVisionRequestUpdate(request: nil, error: error)
      }
    }
  }

  // MARK: Still image processing

  func process(_ cgImage: CGImage) {
    do {
      try visionSequenceHandler.perform(visionBarcodesRequests, on: cgImage)
    } catch {
      handleVisionRequestUpdate(request: nil, error: error)
    }
  }

  // MARK: Callback

  private func handleVisionRequestUpdate(request: VNRequest?, error: Error?) {
    guard let results = request?.results as? [VNBarcodeObservation] else {
      let message = error != nil ? "\(error!)" : "unknownError"
      print("Error scanning image: \(message)")
      let flutterError = FlutterError(
        code: "UNEXPECTED_SCAN_ERROR", message: message, details: error?._code)
      resultHandler(flutterError)
      return
    }

    var unique = Set<String>()
    let barcodes =
      results
      .filter { $0.confidence > confidence && $0.payloadStringValue != nil }
      // consolidate any duplicate scans. Code128 has been observed to produce multiple scans
      .filter { unique.insert($0.symbology.rawValue + $0.payloadStringValue!).inserted }
      .map { observation in
        let boundingBox = DispatchQueue.main.sync {
          cornerPointConverter?(observation) ?? observation.boundingBox
        }

        return [
          flutterVNSymbols[observation.symbology]!, observation.payloadStringValue!, nil,
          boundingBox.minX,
          boundingBox.minY, boundingBox.maxX, boundingBox.maxY,
        ]
      }

    onDetection?()

    resultHandler(barcodes)
  }
}
