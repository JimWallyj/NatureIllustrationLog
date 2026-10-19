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

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Button("Change Background") {
                    isPickingPhoto = true
                }
                .buttonStyle(RaisedButtonStyle())

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
                Spacer()
            }
            .frame(maxWidth: .infinity)
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
}
