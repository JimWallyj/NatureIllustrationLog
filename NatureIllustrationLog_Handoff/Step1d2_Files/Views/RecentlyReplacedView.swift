import SwiftData
import SwiftUI

/// Older versions of files that were replaced by Update, kept for 30 days.
/// Opened from Settings. Tap a file to view it (with Restore and Delete Now
/// buttons), or swipe right to Restore and left to Delete Now.
struct RecentlyReplacedView: View {
    static let keepDays = 30

    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<SubjectFile> { $0.replacedDate != nil }, sort: \SubjectFile.name)
    private var replacedFiles: [SubjectFile]

    @State private var restoreRequest: SubjectFile?
    @State private var deleteRequest: SubjectFile?

    /// Most recently replaced first.
    private var sortedFiles: [SubjectFile] {
        replacedFiles.sorted { ($0.replacedDate ?? .distantPast) > ($1.replacedDate ?? .distantPast) }
    }

    var body: some View {
        List {
            ForEach(sortedFiles) { file in
                NavigationLink {
                    ReplacedFileDetailView(file: file)
                } label: {
                    row(for: file)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        restoreRequest = file
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteRequest = file
                    } label: {
                        Label("Delete Now", systemImage: "trash")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !replacedFiles.isEmpty {
                Text("Tap a file to view it. Swipe right to restore, or left to delete now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .overlay {
            if replacedFiles.isEmpty {
                ContentUnavailableView(
                    "Nothing Recently Replaced",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("When Update replaces a file, the older version is kept here for 30 days.")
                )
            }
        }
        .navigationTitle("Recently Replaced")
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
        .modifier(ReplacedFileActions(restoreRequest: $restoreRequest, deleteRequest: $deleteRequest))
    }

    private func row(for file: SubjectFile) -> some View {
        HStack(spacing: 12) {
            Group {
                if let data = file.coverPhoto?.thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                if let replacedDate = file.replacedDate {
                    Text("Replaced: \(replacedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Days left: \(Self.daysLeft(since: replacedDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 30-day limit

    static func daysLeft(since replacedDate: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: replacedDate, to: .now).day ?? 0
        return max(0, keepDays - days)
    }

    /// Deletes older versions that have been kept for more than 30 days.
    /// Called each time the app starts.
    static func removeExpired(in context: ModelContext) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -keepDays, to: .now) else { return }
        let descriptor = FetchDescriptor<SubjectFile>(predicate: #Predicate { $0.replacedDate != nil })
        let replaced = (try? context.fetch(descriptor)) ?? []
        for file in replaced where (file.replacedDate ?? .now) < cutoff {
            context.delete(file)
        }
        try? context.save()
    }
}

/// An older version opened from Recently Replaced: the usual read-only File
/// View with Restore and Delete Now buttons along the bottom.
struct ReplacedFileDetailView: View {
    let file: SubjectFile

    @Environment(\.dismiss) private var dismiss
    @State private var restoreRequest: SubjectFile?
    @State private var deleteRequest: SubjectFile?

    var body: some View {
        FileDetailView(file: file)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 16) {
                    Button("Restore") {
                        restoreRequest = file
                    }
                    .buttonStyle(RaisedButtonStyle())

                    Button("Delete Now", role: .destructive) {
                        deleteRequest = file
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
            .modifier(ReplacedFileActions(
                restoreRequest: $restoreRequest,
                deleteRequest: $deleteRequest,
                closesScreen: true,
                onFinished: { dismiss() }
            ))
    }
}

/// Restore and Delete Now, with their messages. Shared by the Recently Replaced
/// list and the file view opened from it.
struct ReplacedFileActions: ViewModifier {
    @Binding var restoreRequest: SubjectFile?
    @Binding var deleteRequest: SubjectFile?
    /// True when used on the file's own screen, which closes after the action.
    var closesScreen = false
    var onFinished: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SubjectFile> { $0.replacedDate == nil })
    private var currentFiles: [SubjectFile]

    @State private var originalName = ""
    @State private var restoreName = ""
    @State private var showingRestoreName = false
    @State private var showingRestoreNameTaken = false

    func body(content: Content) -> some View {
        content
            .onChange(of: restoreRequest?.persistentModelID) {
                if let file = restoreRequest { beginRestore(file) }
            }
            .confirmationDialog(
                "Delete \"\(deleteRequest?.name ?? "")\" now?",
                isPresented: Binding(
                    get: { deleteRequest != nil },
                    set: { isPresented in
                        if !isPresented { deleteRequest = nil }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Now", role: .destructive) {
                    if let file = deleteRequest { delete(file) }
                    deleteRequest = nil
                }
                Button("Cancel", role: .cancel) {
                    deleteRequest = nil
                }
            } message: {
                Text("This older version and its photos will be removed. This can't be undone.")
            }
            // Restoring when the name is already used in the File List.
            .alert("Name Already Used", isPresented: $showingRestoreName) {
                TextField("Name", text: $restoreName)
                Button("Restore") { finishRestore() }
                Button("Cancel", role: .cancel) { restoreRequest = nil }
            } message: {
                Text("A file named \"\(originalName)\" is already in your File List. Choose a name for the restored file.")
            }
            .alert("Name Already Used", isPresented: $showingRestoreNameTaken) {
                TextField("Name", text: $restoreName)
                Button("Restore") { finishRestore() }
                Button("Cancel", role: .cancel) { restoreRequest = nil }
            } message: {
                Text("That name is also taken. Please try another.")
            }
    }

    private func beginRestore(_ file: SubjectFile) {
        if isNameAvailable(file.name) {
            restore(file, as: file.name)
        } else {
            originalName = file.name
            restoreName = suggestedName(for: file.name)
            showingRestoreName = true
        }
    }

    private func finishRestore() {
        guard let file = restoreRequest else { return }
        let name = restoreName.trimmingCharacters(in: .whitespacesAndNewlines)
        if isNameAvailable(name) {
            restore(file, as: name)
        } else {
            // Ask again once the first message has closed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showingRestoreNameTaken = true
            }
        }
    }

    /// Puts the older version back in the File List. If the newer version (same
    /// hidden ID) is still there, the restored one becomes a separate file.
    private func restore(_ file: SubjectFile, as name: String) {
        if currentFiles.contains(where: { $0.uniqueID == file.uniqueID }) {
            file.uniqueID = UUID()
        }
        file.name = name
        file.replacedDate = nil
        restoreRequest = nil
        try? modelContext.save()
        onFinished()
    }

    private func delete(_ file: SubjectFile) {
        if closesScreen {
            // Leave the file's screen before removing it.
            onFinished()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                modelContext.delete(file)
                try? modelContext.save()
            }
        } else {
            modelContext.delete(file)
            try? modelContext.save()
        }
    }

    private func isNameAvailable(_ name: String) -> Bool {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return false }
        return !currentFiles.contains { $0.name.caseInsensitiveCompare(wanted) == .orderedSame }
    }

    private func suggestedName(for name: String) -> String {
        var number = 2
        while !isNameAvailable("\(name) (\(number))") {
            number += 1
        }
        return "\(name) (\(number))"
    }
}
