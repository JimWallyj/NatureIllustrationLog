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

    var body: some View {
        List(selection: $selection) {
            ForEach(files) { file in
                NavigationLink(value: file) {
                    HStack(spacing: 12) {
                        thumbnail(for: file)
                        Text(file.name)
                        if file.isReadOnly {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tag(file.persistentModelID)
                .swipeActions {
                    Button(role: .destructive) {
                        pendingDeleteFile = file
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        // Circles appear in front of each file only while selecting.
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
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
                    if allSelected {
                        Button("Deselect All") { selection.removeAll() }
                    } else {
                        Button("Select All") { selection = Set(files.map(\.persistentModelID)) }
                    }
                } else {
                    Button {
                        showingAddFile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                Button {
                    startExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(!isSelecting || selection.isEmpty)

                if isSelecting {
                    Button {
                        showingMultiDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selection.isEmpty)
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
            Text("This removes the photo and notes for this file. This can't be undone.")
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
            Button("Cancel", role: .cancel) {}
        } message: {
            let skipped = selectedFiles.count - sendableFiles.count
            if skipped > 0 {
                Text("\(skipped) of the \(selectedFiles.count) selected files can't be sent (read-only or already on your Mac). Send the other \(sendableFiles.count)?")
            } else {
                Text("Send to My Devices keeps the files editable. Share Read-Only lets others view them but not change them.")
            }
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
    private func export(_ kind: FilePackage.TransferKind) {
        let toSend = sendableFiles
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

    /// Removes the temporary transfer files once the share sheet closes.
    private func cleanUpExports() {
        let folder = lastExportFolder
        lastExportFolder = nil
        if let folder { try? FileManager.default.removeItem(at: folder) }
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
