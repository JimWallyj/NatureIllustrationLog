import AVFoundation
import Photos
import SwiftUI
import UIKit

/// "Take Photo": Apple's standard camera screen, one photo per opening.
/// iPhone/iPad only — hidden on the Mac (and in the Simulator, which has no camera).
///
/// Each photo taken is:
/// - stored in the app like any other photo (see PhotoStorage), dated the
///   moment it was taken, and
/// - also saved at full quality to the Photos library, using the "Add Photos
///   Only" permission (asked once). If that permission is refused, the photo
///   is still added to the app; only the Photos copy is skipped.
enum CameraCapture {
    /// True when this device has a camera the app can use.
    static var isAvailable: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    /// Turns a camera photo into an album photo: the stored photo, a small
    /// thumbnail, and its date (the moment it was taken).
    static func makePhoto(from image: UIImage, taken date: Date) -> PickedPhoto? {
        guard let data = PhotoStorage.storedData(from: image) else { return nil }
        return PickedPhoto(
            data: data,
            thumbnailData: thumbnailData(for: image) ?? data,
            dateTaken: date
        )
    }

    /// A small JPEG (about 400 px on the long side) for lists and grids.
    private static func thumbnailData(for image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, 400 / longest)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let thumbnail = image.preparingThumbnail(of: target) ?? image
        return thumbnail.jpegData(compressionQuality: 0.8)
    }

    /// Saves the full-quality original to the Photos library. Asks for the
    /// "Add Photos Only" permission the first time; if it's refused, nothing
    /// happens (no message each time).
    static func saveOriginalToPhotos(_ image: UIImage, taken date: Date) {
        let save = {
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                request.creationDate = date
            }, completionHandler: nil)
        }
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            save()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                if status == .authorized || status == .limited {
                    save()
                }
            }
        default:
            break
        }
    }
}

extension View {
    /// The "Take Photo" choice. Set `isPresented` to true to start: the app
    /// checks camera access, then opens the camera (or explains why it can't).
    /// `onLoading` runs while the photo is prepared (show the progress
    /// indicator); `onLoaded` gets the photo, ready for the space check.
    func cameraCapture(
        isPresented: Binding<Bool>,
        onLoading: @escaping () -> Void,
        onLoaded: @escaping ([PickedPhoto]) -> Void
    ) -> some View {
        modifier(CameraCaptureModifier(isPresented: isPresented, onLoading: onLoading, onLoaded: onLoaded))
    }
}

private struct CameraCaptureModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onLoading: () -> Void
    let onLoaded: ([PickedPhoto]) -> Void

    @State private var showingCamera = false
    @State private var accessProblem: CameraAccessProblem?

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) {
                guard isPresented else { return }
                isPresented = false
                start()
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker(
                    onCapture: { image in
                        showingCamera = false
                        handle(image)
                    },
                    onCancel: { showingCamera = false }
                )
                .ignoresSafeArea()
                .background(Color.black)
            }
            .alert(
                accessProblem?.title ?? "",
                isPresented: Binding(
                    get: { accessProblem != nil },
                    set: { isShown in
                        if !isShown { accessProblem = nil }
                    }
                ),
                presenting: accessProblem
            ) { problem in
                if problem == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: { problem in
                Text(problem.message)
            }
    }

    /// Opens the camera if access is allowed. The first time, iOS asks.
    private func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            Task {
                // If the user taps "Don't Allow" here, nothing more happens;
                // the next tap on Take Photo explains how to turn it on.
                if await AVCaptureDevice.requestAccess(for: .video) {
                    showingCamera = true
                }
            }
        case .restricted:
            accessProblem = .restricted
        default:
            accessProblem = .denied
        }
    }

    private func handle(_ image: UIImage) {
        let date = Date()
        CameraCapture.saveOriginalToPhotos(image, taken: date)
        onLoading()
        Task {
            await Task.yield()   // let the progress indicator appear first
            let photo = CameraCapture.makePhoto(from: image, taken: date)
            onLoaded(photo.map { [$0] } ?? [])
        }
    }
}

/// Why the camera can't open.
private enum CameraAccessProblem {
    /// The user turned camera access off: explain, with a link to Settings.
    case denied
    /// Blocked by Screen Time or a device profile: the user can't change it
    /// in this app's Settings, so there's no Settings button.
    case restricted

    var title: LocalizedStringKey {
        switch self {
        case .denied: "Camera Access Is Off"
        case .restricted: "Camera Not Available"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .denied: "To take photos in this app, turn on Camera in Settings."
        case .restricted: "The camera is turned off on this device, for example by Screen Time."
        }
    }
}

/// Wraps Apple's standard camera screen (UIImagePickerController).
private struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        // "Use Photo"
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
