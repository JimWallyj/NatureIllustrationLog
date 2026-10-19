import SwiftData
import SwiftUI

/// All the photos in one of a file's albums. Tap a photo to see it full screen
/// (and swipe through the rest). Swipe a row left to delete it, or right to
/// make it the first photo — the one the File Screen and File List show.
struct AlbumView: View {
    let file: SubjectFile
    let kind: AlbumKind

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isPickingPhotos = false
    @State private var isImporting = false
    @State private var viewing: ViewerItem?
    @State private var pendingDelete: AlbumPhoto?

    private var photos: [AlbumPhoto] { file.album(kind) }

    private var title: LocalizedStringKey {
        kind == .subject ? "Photos" : "Illustration Photos"
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    HStack(spacing: 12) {
                        thumbnail(for: photo)
                            .onTapGesture { viewing = ViewerItem(id: index) }
                        PhotoDateRow(photo: photo)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDelete = photo
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if index > 0 {
                            Button {
                                makeFirst(photo)
                            } label: {
                                Label("Set as First", systemImage: "star")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .overlay {
                if photos.isEmpty {
                    ContentUnavailableView(
                        "No Photos Yet",
                        systemImage: "photo",
                        description: Text("Tap + to add photos.")
                    )
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPickingPhotos = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPickingPhotos) {
                PhotoAssetPicker(
                    selectionLimit: 0,
                    onSelectionDone: {
                        isPickingPhotos = false
                        isImporting = true
                    },
                    onPick: { picked in
                        file.appendPhotos(picked, kind: kind, in: modelContext)
                        isImporting = false
                    }
                )
            }
            .fullScreenCover(item: $viewing) { item in
                FullPhotoView(photos: photos, startIndex: item.id)
            }
            .confirmationDialog(
                "Delete this photo?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { isPresented in
                        if !isPresented { pendingDelete = nil }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let photo = pendingDelete {
                        modelContext.delete(photo)
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("This can't be undone.")
            }
            .overlay {
                if isImporting {
                    ImportingOverlay()
                }
            }
        }
    }

    private func thumbnail(for photo: AlbumPhoto) -> some View {
        Group {
            if let image = UIImage(data: photo.thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Moves a photo to the front of the album.
    private func makeFirst(_ photo: AlbumPhoto) {
        let lowest = photos.map(\.sortIndex).min() ?? 0
        photo.sortIndex = lowest - 1
    }
}
