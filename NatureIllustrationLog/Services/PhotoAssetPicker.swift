import Photos
import PhotosUI
import SwiftUI

/// A photo the user picked, plus its date taken if we could resolve it from
/// the underlying Photos asset. (Location is no longer read from the photo;
/// the user pins it by hand instead.)
struct PickedPhoto {
    let image: UIImage
    let dateTaken: Date?
}

/// Wraps PHPickerViewController so we can resolve the picked item's PHAsset
/// and read its creation date. Reading that requires Photos library
/// authorization — if the user hasn't granted it, the image is still returned,
/// just without a date.
struct PhotoAssetPicker: UIViewControllerRepresentable {
    var onPick: (PickedPhoto) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        context.coordinator.dismiss = context.environment.dismiss
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        context.coordinator.dismiss = context.environment.dismiss
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (PickedPhoto) -> Void
        var dismiss: DismissAction?

        init(onPick: @escaping (PickedPhoto) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Cancel: close the sheet through SwiftUI so its state stays in sync.
            guard let result = results.first else {
                dismiss?()
                return
            }

            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                self.resolveDate(for: result, image: image)
            }
        }

        private func resolveDate(for result: PHPickerResult, image: UIImage) {
            guard let assetIdentifier = result.assetIdentifier else {
                deliver(PickedPhoto(image: image, dateTaken: nil))
                return
            }

            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard status == .authorized || status == .limited else {
                deliver(PickedPhoto(image: image, dateTaken: nil))
                return
            }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            deliver(PickedPhoto(image: image, dateTaken: fetchResult.firstObject?.creationDate))
        }

        private func deliver(_ photo: PickedPhoto) {
            DispatchQueue.main.async {
                self.onPick(photo)
            }
        }
    }
}

/// Requests Photos library read access so the date taken can be resolved.
/// Called once from HomeView so the system prompt appears before the user's
/// first Add File attempt.
func requestPhotoLibraryAccessIfNeeded() {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    if status == .notDetermined {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
    }
}
