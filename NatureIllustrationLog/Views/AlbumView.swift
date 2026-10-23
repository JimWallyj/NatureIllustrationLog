import SwiftData
import SwiftUI

/// All the photos in one of a file's albums. Tap a photo to see it full screen
/// (and swipe through the rest). Swipe a row left to delete it, or right to
/// make it the first photo — the one the File Screen and File List show.
/// Right-click (Mac) or long-press (iPhone/iPad) a photo for the same choices.
/// Select mode deletes several photos at once.
struct AlbumView: View {
    let file: SubjectFile
    let kind: AlbumKind

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isPickingPhotos = false
    @State private var isImporting = false
    @State private var viewing: ViewerItem?
    @State private var pendingDelete: AlbumPhoto?
    @State private var photoSpaceNeeded: Int64?
    @State private var isPickingFiles = false

    // Select mode
    @State private var isSelecting = false
    @State private var selection = Set<PersistentIdentifier>()
    @State private var showingDeleteSelected = false

    private var photos: [AlbumPhoto] { file.album(kind) }

    private var title: LocalizedStringKey {
        kind == .subject ? "Photos" : "Illustration Photos"
    }

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    HStack(spacing: 12) {
                        thumbnail(for: photo)
                            .onTapGesture { viewing = ViewerItem(id: index) }
                            .allowsHitTesting(!isSelecting)   // in Select mode a tap checks the row
                        PhotoDateRow(photo: photo, isEditable: !file.isLocked)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(isSelecting)
                    }
                    .tag(photo.persistentModelID)
                    .swipeActions(edge: .trailing) {
                        if !file.isLocked {
                            Button(role: .destructive) {
                                pendingDelete = photo
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if index > 0 && !file.isLocked {
                            Button {
                                makeFirst(photo)
                            } label: {
                                Label("Set as First", systemImage: "star")
                            }
                            .tint(.orange)
                        }
                    }
                    .contextMenu {
                        if !file.isLocked {
                            if index > 0 {
                                Button {
                                    makeFirst(photo)
                                } label: {
                                    Label("Set as First", systemImage: "star")
                                }
                            }
                            Button(role: .destructive) {
                                pendingDelete = photo
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            // Circles appear in front of each photo only while selecting.
            .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
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
            .toolbar { albumToolbar }
            .sheet(isPresented: $isPickingPhotos) {
                PhotoAssetPicker(
                    selectionLimit: 0,
                    onSelectionDone: {
                        isPickingPhotos = false
                        isImporting = true
                    },
                    onPick: { picked in
                        isImporting = false
                        if StorageCheck.hasRoom(forBytes: StorageCheck.bytes(of: picked)) {
                            file.appendPhotos(picked, kind: kind, in: modelContext)
                        } else {
                            photoSpaceNeeded = StorageCheck.bytes(of: picked)
                        }
                    }
                )
            }
            .imageFileImporter(
                isPresented: $isPickingFiles,
                onLoading: { isImporting = true },
                onLoaded: { picked in
                    isImporting = false
                    if StorageCheck.hasRoom(forBytes: StorageCheck.bytes(of: picked)) {
                        file.appendPhotos(picked, kind: kind, in: modelContext)
                    } else {
                        photoSpaceNeeded = StorageCheck.bytes(of: picked)
                    }
                }
            )
            .notEnoughSpaceForPhotosAlert(bytesNeeded: $photoSpaceNeeded)
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
                        file.touch()
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("This can't be undone.")
            }
            .confirmationDialog(
                selection.count == 1 ? Text("Delete 1 photo?") : Text("Delete \(selection.count) photos?"),
                isPresented: $showingDeleteSelected,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteSelected() }
                Button("Cancel", role: .cancel) {}
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

    // MARK: - Toolbar

    /// iPhone/iPad: [<] … [Select] [+]; while selecting: [<] [Select All] [Trash] … [Cancel].
    /// Mac: every button at the top right: [Select] [<] [+]; while selecting:
    /// [Select All] [Trash] [Cancel] [<].
    @ToolbarContentBuilder
    private var albumToolbar: some ToolbarContent {
        #if targetEnvironment(macCatalyst)
        ToolbarItemGroup(placement: .topBarTrailing) {
            if isSelecting {
                selectAllButton
                trashButton
                Button("Cancel") { endSelecting() }
            } else if !file.isLocked {
                Button("Select") { isSelecting = true }
                    .disabled(photos.isEmpty)
            }
            backButton
            if !isSelecting && !file.isLocked {
                addButton
            }
        }
        #else
        ToolbarItemGroup(placement: .topBarLeading) {
            backButton
            if isSelecting {
                selectAllButton
                trashButton
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if isSelecting {
                Button("Cancel") { endSelecting() }
            } else if !file.isLocked {
                Button("Select") { isSelecting = true }
                    .disabled(photos.isEmpty)
                addButton
            }
        }
        #endif
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
        }
    }

    /// "+": Photos Library or Files.
    private var addButton: some View {
        AddPhotosMenu(
            onPhotosLibrary: { isPickingPhotos = true },
            onFiles: { isPickingFiles = true }
        ) {
            Image(systemName: "plus")
        }
    }

    private var allSelected: Bool {
        !photos.isEmpty && selection.count == photos.count
    }

    // Toolbar buttons that change with the selection get an .id tied to it, so
    // the Mac's top bar redraws them right away (it otherwise lags until resized).
    @ViewBuilder
    private var selectAllButton: some View {
        Group {
            if allSelected {
                Button("Deselect All") { selection.removeAll() }
            } else {
                Button("Select All") { selection = Set(photos.map(\.persistentModelID)) }
            }
        }
        .id(allSelected)
    }

    private var trashButton: some View {
        Button {
            if !selection.isEmpty { showingDeleteSelected = true }
        } label: {
            Image(systemName: "trash")
        }
        .disabled(selection.isEmpty)
        .keyboardShortcut(.delete, modifiers: [])
        .id(selection.isEmpty)
    }

    // MARK: - Actions

    private func endSelecting() {
        isSelecting = false
        selection.removeAll()
    }

    private func deleteSelected() {
        for photo in photos where selection.contains(photo.persistentModelID) {
            modelContext.delete(photo)
        }
        file.touch()
        endSelecting()
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
        file.touch()
    }
}
