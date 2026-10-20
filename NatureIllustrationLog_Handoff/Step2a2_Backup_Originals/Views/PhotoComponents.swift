import SwiftUI

/// The large first photo of an album, as shown on the File Screen.
struct CoverPhotoView: View {
    let photo: AlbumPhoto

    var body: some View {
        if let image = UIImage(data: photo.imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// A photo's date. Tap the date to change it. A photo with no date yet shows
/// a labeled date picker so the user can enter one by hand.
struct PhotoDateRow: View {
    @Bindable var photo: AlbumPhoto
    /// False for read-only files: the date is shown but can't be changed.
    var isEditable: Bool = true

    var body: some View {
        if !isEditable {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                if let date = photo.date {
                    Text(date, format: .dateTime.year().month(.abbreviated).day())
                } else {
                    Text("No date")
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        } else if photo.date != nil {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                    .labelsHidden()
                Spacer(minLength: 0)
            }
        } else {
            DatePicker("Date", selection: dateBinding, displayedComponents: .date)
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { photo.date ?? Date() },
            set: {
                photo.date = $0
                photo.file?.touch()
            }
        )
    }
}

/// Dimmed overlay with a spinner, shown while picked photos are being prepared.
struct ImportingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView("Importing photos…")
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

extension View {
    /// The "Not Enough Space" message shown when picked photos won't fit on the device.
    func notEnoughSpaceForPhotosAlert(bytesNeeded: Binding<Int64?>) -> some View {
        alert(
            "Not Enough Space",
            isPresented: Binding(
                get: { bytesNeeded.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented { bytesNeeded.wrappedValue = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("There isn't enough space on this device to add these photos (about \(StorageCheck.formatted(bytesNeeded.wrappedValue ?? 0)) needed). Free up space, or offload some files to your Mac.")
        }
    }
}
