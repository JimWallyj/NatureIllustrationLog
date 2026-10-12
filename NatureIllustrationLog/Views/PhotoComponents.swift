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

/// A photo's date: shown as text when it has one, or as a date picker so the
/// user can enter it by hand when it doesn't.
struct PhotoDateRow: View {
    @Bindable var photo: AlbumPhoto

    var body: some View {
        if let date = photo.date {
            Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                .foregroundStyle(.secondary)
        } else {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { photo.date ?? Date() },
                    set: { photo.date = $0 }
                ),
                displayedComponents: .date
            )
        }
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
