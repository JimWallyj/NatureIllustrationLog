import Photos
import PhotosUI
import SwiftUI

/// A photo the user picked, along with whatever metadata we could resolve
/// from the underlying Photos asset (date taken, location).
struct PickedPhoto {
    let image: UIImage
    let dateTaken: Date?
    let latitude: Double?
    let longitude: Double?
}

/// Wraps PHPickerViewController (rather than the plain SwiftUI PhotosPicker)
/// so we can resolve the picked item's PHAsset and read its creation date and
/// location. Reading that metadata requires Photos library authorization —
/// if the user hasn't granted it, we still return the image, just without
/// date/location (see AddFileView / EditHomeView for how callers handle that).
struct PhotoAssetPicker: UIViewControllerRepresentable {
    var onPick: (PickedPhoto) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (PickedPhoto) -> Void

        init(onPick: @escaping (PickedPhoto) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
           // picker.dismiss(animated: true)
            guard let result = results.first else { return }

            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                self.resolveMetadata(for: result, image: image)
            }
        }

        private func resolveMetadata(for result: PHPickerResult, image: UIImage) {
            guard let assetIdentifier = result.assetIdentifier else {
                deliver(PickedPhoto(image: image, dateTaken: nil, latitude: nil, longitude: nil))
                return
            }

            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard status == .authorized || status == .limited else {
                // Not authorized to read asset metadata — still hand back the image.
                deliver(PickedPhoto(image: image, dateTaken: nil, latitude: nil, longitude: nil))
                return
            }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            guard let asset = fetchResult.firstObject else {
                deliver(PickedPhoto(image: image, dateTaken: nil, latitude: nil, longitude: nil))
                return
            }

            deliver(PickedPhoto(
                image: image,
                dateTaken: asset.creationDate,
                latitude: asset.location?.coordinate.latitude,
                longitude: asset.location?.coordinate.longitude
            ))
        }

        private func deliver(_ photo: PickedPhoto) {
            DispatchQueue.main.async {
                self.onPick(photo)
            }
        }
    }
}

/// Requests Photos library read access so date/location metadata can be
/// resolved. Call this once, e.g. from HomeView's .task, so the system
/// permission prompt appears before the user's first Add File attempt.
func requestPhotoLibraryAccessIfNeeded() {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    if status == .notDetermined {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
    }
}
