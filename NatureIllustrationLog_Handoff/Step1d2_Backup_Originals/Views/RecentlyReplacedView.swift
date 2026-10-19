import SwiftData
import SwiftUI

/// Older versions of files that were replaced by Update, kept for 30 days.
/// Opened from Settings. Swipe right to Restore, left to Delete Now; tap to view.
struct RecentlyReplacedView: View {
    static let keepDays = 30

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<SubjectFile> { $0.replacedDate != nil }, sort: \SubjectFile.name)
    private var replacedFiles: [SubjectFile]

    @Query(filter: #Predicate<SubjectFile> { $0.replacedDate == nil })
    private var currentFiles: [SubjectFile]

    @State private var pendingDelete: SubjectFile?
    @State private var restoring: SubjectFile?
    @State private var restoringOriginalName = ""
    @State private var restoreName = ""
    @State private var showingRestoreName = false
    @State private var showingRestoreNameTaken = false

    /// Most recently replaced first.
    private var sortedFiles: [SubjectFile] {
        replacedFiles.sorted { ($0.replacedDate ?? .distantPast) > ($1.replacedDate ?? .distantPast) }
    }

    var body: some View {
        List {
            ForEach(sortedFiles) { file in
                NavigationLink {
                    FileDetailView(file: file)
                } label: {
                    row(for: file)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        startRestore(file)
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingDelete = file
                    } label: {
                        Label("Delete Now", systemImage: "trash")
                    }
                }
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
        .confirmationDialog(
            "Delete \"\(pendingDelete?.name ?? "")\" now?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { isPresented in
                    if !isPresented { pendingDelete = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Now", role: .destructive) {
                if let file = pendingDelete {
                    modelContext.delete(file)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("This older version and its photos will be removed. This can't be undone.")
        }
        // Restoring when the name is already used in the File List.
        .alert("Name Already Used", isPresented: $showingRestoreName) {
            TextField("Name", text: $restoreName)
            Button("Restore") { finishRestore() }
            Button("Cancel", role: .cancel) { restoring = nil }
        } message: {
            Text("A file named \"\(restoringOriginalName)\" is already in your File List. Choose a name for the restored file.")
        }
        .alert("Name Already Used", isPresented: $showingRestoreNameTaken) {
            TextField("Name", text: $restoreName)
            Button("Restore") { finishRestore() }
            Button("Cancel", role: .cancel) { restoring = nil }
        } message: {
            Text("That name is also taken. Please try another.")
        }
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

    // MARK: - Restore

    private func startRestore(_ file: SubjectFile) {
        if isNameAvailable(file.name) {
            restore(file, as: file.name)
        } else {
            restoring = file
            restoringOriginalName = file.name
            restoreName = suggestedName(for: file.name)
            showingRestoreName = true
        }
    }

    private func finishRestore() {
        guard let file = restoring else { return }
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
        restoring = nil
        try? modelContext.save()
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
