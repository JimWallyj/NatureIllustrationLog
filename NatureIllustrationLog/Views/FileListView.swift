import SwiftData
import SwiftUI

struct FileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationCoordinator.self) private var coordinator
    @Query(sort: \SubjectFile.name) private var files: [SubjectFile]
    @State private var showingAddFile = false
    @State private var pendingDeleteFile: SubjectFile?

    var body: some View {
        List {
            ForEach(files) { file in
                NavigationLink(value: file) {
                    HStack(spacing: 12) {
                        thumbnail(for: file)
                        Text(file.name)
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
        .navigationTitle("Illustration Projects")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingAddFile = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
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
    }

    private func thumbnail(for file: SubjectFile) -> some View {
        Group {
            if let uiImage = UIImage(data: file.photoData) {
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

#Preview {
    NavigationStack {
        FileListView()
    }
    .modelContainer(for: SubjectFile.self, inMemory: true)
    .environment(NavigationCoordinator())
}
