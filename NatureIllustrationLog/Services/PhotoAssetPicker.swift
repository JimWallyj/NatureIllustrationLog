import Photos
import PhotosUI
import SwiftUI

/// A photo the user picked: the full-size JPEG, a small thumbnail for lists,
/// and its date taken if it could be read from the Photos asset.
struct PickedPhoto: Identifiable {
    let id = UUID()
    let data: Data
    let thumbnailData: Data
    let dateTaken: Date?
}

/// Wraps PHPickerViewController so one or several photos can be picked (in the
/// order they were tapped) and each one's creation date can be read from its
/// Photos asset. Reading dates requires Photos library authorization — without
/// it the photos are still returned, just with no date.
///
/// - selectionLimit: 1 for a single photo, 0 for no limit.
/// - onSelectionDone: called right away when the user taps Add, so the caller
///   can close the picker and show a progress indicator while photos load.
/// - onPick: called once every photo has been loaded.
struct PhotoAssetPicker: UIViewControllerRepresentable {
    var selectionLimit: Int = 1
    var onSelectionDone: () -> Void = {}
    var onPick: ([PickedPhoto]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = selectionLimit
        if selectionLimit != 1 {
            config.selection = .ordered
        }
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        context.coordinator.dismiss = context.environment.dismiss
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        context.coordinator.dismiss = context.environment.dismiss
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionDone: onSelectionDone, onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelectionDone: () -> Void
        let onPick: ([PickedPhoto]) -> Void
        var dismiss: DismissAction?

        init(onSelectionDone: @escaping () -> Void, onPick: @escaping ([PickedPhoto]) -> Void) {
            self.onSelectionDone = onSelectionDone
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Cancel: close the sheet through SwiftUI so its state stays in sync.
            guard !results.isEmpty else {
                dismiss?()
                return
            }

            onSelectionDone()

            let dates = creationDates(for: results)
            let providers = results.map { $0.itemProvider }
            loadNext(providers: providers, dates: dates, index: 0, collected: [])
        }

        /// Loads the photos one at a time, in order, so memory use stays low
        /// even when several large camera photos are picked.
        private func loadNext(providers: [NSItemProvider], dates: [Date?], index: Int, collected: [PickedPhoto]) {
            guard index < providers.count else {
                DispatchQueue.main.async {
                    self.onPick(collected)
                }
                return
            }

            providers[index].loadObject(ofClass: UIImage.self) { object, _ in
                var updated = collected
                if let image = object as? UIImage,
                   let photo = self.makePhoto(from: image, date: dates[index]) {
                    updated.append(photo)
                }
                self.loadNext(providers: providers, dates: dates, index: index + 1, collected: updated)
            }
        }

        private func makePhoto(from image: UIImage, date: Date?) -> PickedPhoto? {
            guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
            return PickedPhoto(
                data: data,
                thumbnailData: thumbnailData(for: image) ?? data,
                dateTaken: date
            )
        }

        /// A small JPEG (about 400 px on the long side) for lists and grids.
        private func thumbnailData(for image: UIImage) -> Data? {
            let longest = max(image.size.width, image.size.height)
            guard longest > 0 else { return nil }
            let scale = min(1, 400 / longest)
            let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let thumbnail = image.preparingThumbnail(of: target) ?? image
            return thumbnail.jpegData(compressionQuality: 0.8)
        }

        /// Dates for each picked photo, in the same order as `results`.
        private func creationDates(for results: [PHPickerResult]) -> [Date?] {
            let noDates: [Date?] = results.map { _ in nil }

            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard status == .authorized || status == .limited else { return noDates }

            let identifiers = results.compactMap { $0.assetIdentifier }
            guard !identifiers.isEmpty else { return noDates }

            var dateByIdentifier: [String: Date] = [:]
            PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                .enumerateObjects { asset, _, _ in
                    if let date = asset.creationDate {
                        dateByIdentifier[asset.localIdentifier] = date
                    }
                }

            return results.map { result in
                result.assetIdentifier.flatMap { dateByIdentifier[$0] }
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
