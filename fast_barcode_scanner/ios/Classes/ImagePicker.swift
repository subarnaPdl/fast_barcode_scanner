import PhotosUI

@MainActor
protocol ImagePicker {
  func show(over viewController: UIViewController) async -> UIImage?
}

@available(iOS 14, *)
class PHImagePicker: ImagePicker, PHPickerViewControllerDelegate {

  private var continuation: CheckedContinuation<UIImage?, Never>?

  func show(over viewController: UIViewController) async -> UIImage? {
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.preferredAssetRepresentationMode = .current

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self

    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      viewController.present(picker, animated: true)
    }
  }

  func show(over viewController: UIViewController) {
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.preferredAssetRepresentationMode = .current

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    viewController.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)

    guard let itemProvider = results.first?.itemProvider,
      itemProvider.canLoadObject(ofClass: UIImage.self)
    else {
      continuation?.resume(returning: nil)
      return
    }

    itemProvider.loadObject(ofClass: UIImage.self) { object, error in
      guard error == nil else {
        print("Error loading object \(error!)")
        self.continuation?.resume(returning: nil)
        return
      }

      self.continuation?.resume(returning: object as? UIImage)
    }
  }
}

class UIImagePicker: NSObject, ImagePicker, UIImagePickerControllerDelegate,
  UINavigationControllerDelegate
{
  private var continuation: CheckedContinuation<UIImage?, Never>?

  func show(over viewController: UIViewController) async -> UIImage? {
    let picker = UIImagePickerController()
    picker.delegate = self
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
      viewController.present(picker, animated: true)
    }
  }

  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    picker.dismiss(animated: true)
    continuation?.resume(returning: info[.originalImage] as? UIImage)
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
    continuation?.resume(returning: nil)
  }
}
