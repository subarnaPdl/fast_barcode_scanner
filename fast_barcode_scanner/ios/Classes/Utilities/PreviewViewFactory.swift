import AVFoundation
import Flutter

class PreviewViewFactory: NSObject, FlutterPlatformViewFactory {
  var session: AVCaptureSession?

  var preview: PreviewView?

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    let view = PreviewView(frame: frame)
    view.session = session
    preview = view
    return view
  }
}
