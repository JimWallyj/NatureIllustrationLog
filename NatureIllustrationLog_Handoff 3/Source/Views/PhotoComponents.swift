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

    var body: some View {
        if photo.date != nil {
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
            set: { photo.date = $0 }
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
