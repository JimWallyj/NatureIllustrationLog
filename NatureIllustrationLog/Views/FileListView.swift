import SwiftData
import SwiftUI

struct FileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationCoordinator.self) private var coordinator
    // Older versions waiting in Recently Replaced are not shown here.
    @Query(filter: #Predicate<SubjectFile> { $0.replacedDate == nil }, sort: \SubjectFile.name)
    private var files: [SubjectFile]
    @State private var showingAddFile = false
    @State private var pendingDeleteFile: SubjectFile?

    // Select mode and export
    @State private var isSelecting = false
    @State private var selection = Set<PersistentIdentifier>()
    @State private var showingExportOptions = false
    @State private var showingCantSend = false
    @State private var showingExportError = false
    @State private var isPreparing = false
    @State private var shareBatch: ExportBatch?
    @State private var lastExportFolder: URL?
    @State private var showingMultiDelete = false

    // Offload ("Send to Mac and Free Up Space", iPhone/iPad only)
    @State private var offloadCandidates: [PersistentIdentifier] = []
    @State private var offloadSendCompleted = false
    @State private var shareResultReceived = false
    @State private var shareWindowClosed = false
    @State private var showingArrivalQuestion = false

    var body: some View {
        List {
            ForEach(files) { file in
                Group {
                    if isSelecting {
                        // Select mode: each click checks or unchecks this file
                        // only (no Shift or Command needed, on iPhone and Mac).
                        HStack(spacing: 12) {
                            SelectionCircle(isSelected: selection.contains(file.persistentModelID))
                            fileRow(file)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { toggleSelection(file.persistentModelID) }
                    } else {
                        NavigationLink(value: file) {
                            fileRow(file)
                        }
                    }
                }
                // Right-click (Mac) or long-press (iPhone/iPad).
                .contextMenu {
                    Button {
                        coordinator.path.append(file)
                    } label: {
                        Label("Open", systemImage: "doc.text")
                    }
                    if !file.isReadOnly && !file.isPlaceholder {
                        Button {
                            export(.ownDevices, only: [file])
                        } label: {
                            Label("Send to My Devices", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            export(.readOnly, only: [file])
                        } label: {
                            Label("Share Read-Only", systemImage: "lock")
                        }
                        if Self.canOffload {
                            Button {
                                export(.ownDevices, only: [file], offload: true)
                            } label: {
                                Label("Send to Mac and Free Up Space", systemImage: "laptopcomputer.and.arrow.down")
                            }
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        pendingDeleteFile = file
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        pendingDeleteFile = file
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .overlay {
            if files.isEmpty {
                ContentUnavailableView(
                    "No Files Yet",
                    systemImage: "leaf",
                    description: Text("Tap + to add your first nature subject.")
                )
            }
        }
        .overlay {
            if isPreparing {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("Preparing files…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .navigationTitle("Illustration Projects")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                if isSelecting {
                    // .id makes the Mac's top bar redraw these as the selection changes.
                    Group {
                        if allSelected {
                            Button("Deselect All") { selection.removeAll() }
                        } else {
                            Button("Select All") { selection = Set(files.map(\.persistentModelID)) }
                        }
                    }
                    .id(allSelected)
                } else {
                    Button {
                        showingAddFile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                Button {
                    if isSelecting && !selection.isEmpty { startExport() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(!isSelecting || selection.isEmpty)
                .id(isSelecting && !selection.isEmpty)

                if isSelecting {
                    Button {
                        if !selection.isEmpty { showingMultiDelete = true }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selection.isEmpty)
                    .keyboardShortcut(.delete, modifiers: [])   // Mac: the Delete key
                    .id(selection.isEmpty)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSelecting {
                    Button("Cancel") { endSelecting() }
                } else {
                    Button("Select") { isSelecting = true }
                        .disabled(files.isEmpty)
                }
                Button {
                    coordinator.goHome()
                } label: {
                    Image(systemName: "house")
                }
            }
        }
        .sheet(isPresented: $showingAddFile) {
            AddFileView()
        }
        .confirmationDialog(
            "Delete \"\(pendingDeleteFile?.name ?? "")\"?",
            isPresented: Binding(
                get: { pendingDeleteFile != nil },
                set: { isPresented in
                    if !isPresented { pendingDeleteFile = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let file = pendingDeleteFile {
                    modelContext.delete(file)
                }
                pendingDeleteFile = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteFile = nil
            }
        } message: {
            if pendingDeleteFile?.isPlaceholder == true {
                Text("This removes the placeholder from this device. The full file on your Mac is not affected.")
            } else {
                Text("This removes the photo and notes for this file. This can't be undone.")
            }
        }
        .confirmationDialog(
            selectedFiles.count == 1 ? Text("Delete 1 file?") : Text("Delete \(selectedFiles.count) files?"),
            isPresented: $showingMultiDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if selectedFiles.contains(where: \.isPlaceholder) {
                Text("This removes their photos and notes. This can't be undone. Full files on your Mac are not affected.")
            } else {
                Text("This removes their photos and notes. This can't be undone.")
            }
        }
        .confirmationDialog("Send Files", isPresented: $showingExportOptions, titleVisibility: .visible) {
            Button("Send to My Devices") { export(.ownDevices) }
            Button("Share Read-Only") { export(.readOnly) }
            if Self.canOffload {
                Button("Send to Mac and Free Up Space") { export(.ownDevices, offload: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let skipped = selectedFiles.count - sendableFiles.count
            if skipped > 0 {
                Text("\(skipped) of the \(selectedFiles.count) selected files can't be sent (read-only or already on your Mac). Send the other \(sendableFiles.count)?")
            } else if Self.canOffload {
                Text("Send to My Devices keeps the files editable. Share Read-Only lets others view them but not change them. Send to Mac and Free Up Space sends them to your Mac, then keeps only a lightweight copy here.")
            } else {
                Text("Send to My Devices keeps the files editable. Share Read-Only lets others view them but not change them.")
            }
        }
        // After an offload send: remove the full photos only once the user confirms.
        .alert(
            offloadCandidates.count == 1 ? Text("Has this file arrived on your Mac?") : Text("Have these files arrived on your Mac?"),
            isPresented: $showingArrivalQuestion
        ) {
            Button("Yes") { finishOffload() }
            Button("Not Yet", role: .cancel) { offloadCandidates = [] }
        } message: {
            Text("Choose Yes only after checking that it's on your Mac. The full-size photos will then be removed from this device; the name, notes, dates, location, and small thumbnails stay here.")
        }
        .alert("Can't Send Files", isPresented: $showingCantSend) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The selected files can't be sent (read-only or already on your Mac).")
        }
        .alert("Couldn't Prepare Files", isPresented: $showingExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Something went wrong while preparing the files to send. Please try again.")
        }
        .sheet(item: $shareBatch, onDismiss: cleanUpExports) { batch in
            ShareSheet(items: batch.urls) { completed in
                if completed {
                    endSelecting()
                }
                offloadSendCompleted = completed
                shareResultReceived = true
                resolveOffloadIfReady()
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Selection

    private var allSelected: Bool {
        !files.isEmpty && selection.count == files.count
    }

    private var selectedFiles: [SubjectFile] {
        files.filter { selection.contains($0.persistentModelID) }
    }

    /// Read-only files and placeholders can be checked but not sent.
    private var sendableFiles: [SubjectFile] {
        selectedFiles.filter { !$0.isReadOnly && !$0.isPlaceholder }
    }

    private func deleteSelected() {
        for file in selectedFiles {
            modelContext.delete(file)
        }
        endSelecting()
    }

    private func fileRow(_ file: SubjectFile) -> some View {
        HStack(spacing: 12) {
            thumbnail(for: file)
            Text(file.name)
            if file.isPlaceholder {
                OnMacBadge()
            }
            if file.isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleSelection(_ id: PersistentIdentifier) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    private func endSelecting() {
        isSelecting = false
        selection.removeAll()
    }

    // MARK: - Export

    private func startExport() {
        if sendableFiles.isEmpty {
            showingCantSend = true
        } else {
            showingExportOptions = true
        }
    }

    /// Writes one transfer file per selected file, then opens the share sheet.
    private func export(_ kind: FilePackage.TransferKind, only files: [SubjectFile]? = nil, offload: Bool = false) {
        let toSend = files ?? sendableFiles
        offloadCandidates = offload ? toSend.map(\.persistentModelID) : []
        offloadSendCompleted = false
        shareResultReceived = false
        shareWindowClosed = false
        isPreparing = true
        Task {
            var folder: URL?
            do {
                let exportFolder = try FilePackage.makeExportFolder()
                folder = exportFolder
                var urls: [URL] = []
                for file in toSend {
                    urls.append(try FilePackage.write(file, kind: kind, to: exportFolder))
                    await Task.yield()   // keep the progress indicator moving
                }
                isPreparing = false
                lastExportFolder = exportFolder
                shareBatch = ExportBatch(folder: exportFolder, urls: urls)
            } catch {
                if let folder { try? FileManager.default.removeItem(at: folder) }
                isPreparing = false
                showingExportError = true
            }
        }
    }

    /// The share window has closed. The temporary transfer files are kept for
    /// now (the Mac's AirDrop and Mail read them after the window closes) and
    /// are removed later by FilePackage.removeOldExportFolders().
    private func cleanUpExports() {
        lastExportFolder = nil
        shareWindowClosed = true
        resolveOffloadIfReady()
    }

    /// For an offload, asks "Has this file arrived on your Mac?" once the share
    /// window has closed. iOS doesn't reliably report whether an AirDrop was
    /// sent, so the app always asks; the user's "Yes" is the confirmation, and
    /// "Not Yet" (e.g. after cancelling) removes nothing.
    private func resolveOffloadIfReady() {
        guard !offloadCandidates.isEmpty, shareWindowClosed, !showingArrivalQuestion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if !offloadCandidates.isEmpty {
                showingArrivalQuestion = true
            }
        }
    }

    /// Offloading is for freeing space on iPhone/iPad; the Mac keeps full files.
    static var canOffload: Bool {
        #if targetEnvironment(macCatalyst)
        false
        #else
        true
        #endif
    }

    /// "Yes, it arrived": remove the full-size photos and keep a read-only
    /// placeholder (name, notes, dates, location, thumbnails) with an "On Mac" badge.
    private func finishOffload() {
        for file in files where offloadCandidates.contains(file.persistentModelID) {
            for photo in file.photos {
                photo.imageData = nil
            }
            file.isPlaceholder = true
        }
        offloadCandidates = []
        try? modelContext.save()
    }

    private func thumbnail(for file: SubjectFile) -> some View {
        Group {
            if let data = file.coverPhoto?.thumbnailData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 44, height: 44)
            }
        }
    }
}

/// One batch of transfer files waiting in the share sheet.
struct ExportBatch: Identifiable {
    let id = UUID()
    let folder: URL
    let urls: [URL]
}

#Preview {
    NavigationStack {
        FileListView()
    }
    .modelContainer(for: SubjectFile.self, inMemory: true)
    .environment(NavigationCoordinator())
}
