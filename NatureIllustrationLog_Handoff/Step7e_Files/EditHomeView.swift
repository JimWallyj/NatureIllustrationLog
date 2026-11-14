import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The Settings screen (formerly "Edit Home"), opened from the gear on Home.
/// The struct and file keep their original name so no Xcode file changes are needed.
struct EditHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ImportManager.self) private var importer
    @AppStorage("homeBackgroundFilename") private var backgroundFilename: String = ""
    @State private var isPickingPhoto = false
    @State private var isPickingImportFiles = false
    @Query(filter: #Predicate<SubjectFile> { $0.replacedDate != nil })
    private var replacedFiles: [SubjectFile]
    @Environment(\.modelContext) private var modelContext
    @State private var showingOptimizeQuestion = false
    @State private var optimizeProgress: (done: Int, total: Int)?
    @State private var optimizeResult: PhotoStorage.OptimizeResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Button("Import Files") {
                    isPickingImportFiles = true
                }
                .buttonStyle(RaisedButtonStyle())

                NavigationLink {
                    RecentlyReplacedView()
                } label: {
                    Text("Recently Replaced (\(replacedFiles.count))")
                }
                .buttonStyle(RaisedButtonStyle())
                .disabled(replacedFiles.isEmpty)

                Button("Change Background") {
                    isPickingPhoto = true
                }
                .buttonStyle(RaisedButtonStyle())

                Button("Optimize Photo Storage") {
                    showingOptimizeQuestion = true
                }
                .buttonStyle(RaisedButtonStyle())
                .disabled(optimizeProgress != nil)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .overlay {
                if let optimizeProgress {
                    VStack(spacing: 12) {
                        ProgressView(value: Double(optimizeProgress.done), total: Double(max(optimizeProgress.total, 1)))
                        Text("Optimizing photos… \(optimizeProgress.done) of \(optimizeProgress.total)")
                            .font(.callout)
                    }
                    .padding(24)
                    .frame(maxWidth: 320)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .alert("Optimize Photo Storage?", isPresented: $showingOptimizeQuestion) {
                Button("Optimize") { optimizePhotos() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Photos already in the app are resized to at most 4096 pixels on the longest side and saved in a smaller format. This saves space on this device but can't be undone. The originals in your Photos library are not affected.")
            }
            .alert("Photo Storage Optimized", isPresented: Binding(
                get: { optimizeResult != nil },
                set: { if !$0 { optimizeResult = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let optimizeResult, optimizeResult.photosChanged > 0 {
                    Text("\(optimizeResult.photosChanged) photos were optimized, saving \(StorageCheck.formatted(optimizeResult.bytesSaved)).")
                } else {
                    Text("Your photos are already optimized.")
                }
            }
            .navigationTitle("Settings")
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
                // "Help" at the top right: a menu with the support page
                // (same item as the Mac's Help menu).
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Help") {
                        Button {
                            SupportLinks.openHelp()
                        } label: {
                            Label("Nature Illustration Log Help", systemImage: "questionmark.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $isPickingPhoto) {
                PhotoAssetPicker(
                    selectionLimit: 1,
                    onSelectionDone: {
                        isPickingPhoto = false
                    },
                    onPick: { picked in
                        guard let photo = picked.first else { return }
                        if let filename = HomeBackgroundStore.replace(photo.data, previousFilename: backgroundFilename) {
                            backgroundFilename = filename
                        }
                    }
                )
            }
            // Pick one or more ".natlog" files; the import starts on Home once
            // this screen closes.
            .fileImporter(
                isPresented: $isPickingImportFiles,
                allowedContentTypes: [.natureLogFile],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result, !urls.isEmpty {
                    importer.receive(urls)
                    dismiss()
                }
            }
        }
    }

    /// Runs "Optimize Photo Storage", showing progress, then the space saved.
    private func optimizePhotos() {
        optimizeProgress = (0, 0)
        Task {
            let result = await PhotoStorage.optimizeAll(in: modelContext) { done, total in
                optimizeProgress = (done, total)
            }
            optimizeProgress = nil
            optimizeResult = result
        }
    }
}
