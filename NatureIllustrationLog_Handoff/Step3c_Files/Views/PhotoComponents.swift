import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The large first photo of an album, as shown on the File Screen.
struct CoverPhotoView: View {
    let photo: AlbumPhoto

    var body: some View {
        if photo.imageData == nil, let thumbnail = UIImage(data: photo.thumbnailData) {
            // Placeholder: the full photo is on the Mac; show the small copy.
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottom) {
                    OnMacNote()
                        .padding(8)
                }
        } else if let data = photo.imageData, let image = UIImage(data: data) {
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
    @State private var showingDateChoice = false

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
        } else {
            // Tap the date (or the red "Set date") to open the date panel.
            HStack(spacing: 6) {
                Button {
                    showingDateChoice = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        if let date = photo.date {
                            Text(date, format: .dateTime.year().month(.abbreviated).day())
                        } else {
                            Text("Set date")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .buttonStyle(.borderless)
                Spacer(minLength: 0)
            }
            .sheet(isPresented: $showingDateChoice) {
                DateChoiceSheet(title: "Date Taken", initialDate: photo.date ?? Date()) { chosen in
                    photo.date = chosen
                    photo.file?.touch()
                }
            }
        }
    }
}

/// A small panel with a full calendar and Cancel / Done. Done uses whatever
/// date is showing — including today — which the pop-up date field can't do
/// (it only reports a change, and on the Mac it can leave its pop-up open).
struct DateChoiceSheet: View {
    let title: LocalizedStringKey
    let onDone: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(title: LocalizedStringKey, initialDate: Date, onDone: @escaping (Date) -> Void) {
        self.title = title
        self.onDone = onDone
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onDone(date)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
        }
        .frame(minWidth: 340, minHeight: 420)
        .presentationDetents([.medium, .large])
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

/// Where the "Open Settings" button in the Photos-access message goes:
/// this app's page in iPhone/iPad Settings, or on the Mac, System Settings →
/// Privacy & Security → Photos.
enum SystemSettingsLink {
    static var photosAccess: URL? {
        #if targetEnvironment(macCatalyst)
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")
        #else
        URL(string: UIApplication.openSettingsURLString)
        #endif
    }
}

/// The "Add Photos" choices: Photos Library (the photo picker) or Files
/// (image files from iCloud Drive, Downloads, On My iPhone, or Mac folders).
struct AddPhotosMenu<MenuLabel: View>: View {
    let onPhotosLibrary: () -> Void
    let onFiles: () -> Void
    @ViewBuilder let label: MenuLabel

    var body: some View {
        Menu {
            Button {
                onPhotosLibrary()
            } label: {
                Label("Photos Library", systemImage: "photo.on.rectangle")
            }
            Button {
                onFiles()
            } label: {
                Label("Files", systemImage: "folder")
            }
        } label: {
            label
        }
    }
}

extension View {
    /// The "Files" choice: pick one or more image files. `onLoading` runs while
    /// they're read (show the progress indicator); `onLoaded` gets the photos.
    func imageFileImporter(
        isPresented: Binding<Bool>,
        onLoading: @escaping () -> Void,
        onLoaded: @escaping ([PickedPhoto]) -> Void
    ) -> some View {
        fileImporter(
            isPresented: isPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result, !urls.isEmpty else { return }
            onLoading()
            Task {
                let photos = await ImageFileLoader.loadPhotos(from: urls)
                onLoaded(photos)
            }
        }
    }
}

/// The circle shown in front of each row in Select mode: filled with a
/// checkmark when the row is checked, empty when not.
struct SelectionCircle: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
    }
}

/// "Full-size photo is on your Mac." — shown over a placeholder's photos.
struct OnMacNote: View {
    var body: some View {
        Label("Full-size photo is on your Mac.", systemImage: "laptopcomputer")
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
    }
}

/// The small "On Mac" badge shown next to an offloaded file's name.
struct OnMacBadge: View {
    var body: some View {
        Label("On Mac", systemImage: "laptopcomputer")
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }
}

/// Runs `action` a moment later, after a confirmation dialog has fully closed.
/// On the Mac, changing the screen while the dialog is still closing can leave
/// the window ignoring the '<' button until Esc is pressed.
func afterDialogCloses(_ action: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: action)
}
