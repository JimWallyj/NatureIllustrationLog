import Foundation
import SwiftData

/// Brings received ".natlog" transfer files into the app, one at a time,
/// asking the user what to do whenever an incoming file's name is already
/// taken. Files arrive either by tapping one in AirDrop, Files, Messages, or
/// Mail, or through "Import Files" on the Settings screen.
@Observable
final class ImportManager {

    /// An incoming file whose name is already used on this device.
    struct Conflict: Identifiable {
        let id = UUID()
        let incomingName: String
        let suggestedName: String
        /// True when more files are still waiting in this transfer.
        let canApplyToAll: Bool
    }

    enum ConflictChoice {
        case useSuggested
        case useName(String)
        case skip
        case cancelTransfer
    }

    struct Summary: Identifiable {
        let id = UUID()
        var imported = 0
        var skipped = 0
        var unreadable = 0
    }

    struct SpaceProblem: Identifiable {
        let id = UUID()
        let fileCount: Int
        let bytesNeeded: Int64
    }

    // What the screens show
    private(set) var conflict: Conflict?
    var summary: Summary?
    var spaceProblem: SpaceProblem?
    private(set) var isImporting = false

    @ObservationIgnored private var pending: [URL] = []
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var conflictContinuation: CheckedContinuation<(ConflictChoice, Bool), Never>?

    // MARK: - Starting

    /// Adds received files to the waiting list.
    func receive(_ urls: [URL]) {
        pending.append(contentsOf: urls)
    }

    /// Starts importing whatever is waiting, unless an import is already running.
    func startPending(in context: ModelContext) {
        guard !isImporting, !pending.isEmpty else { return }
        let urls = pending
        pending.removeAll()
        self.context = context
        isImporting = true
        Task {
            await run(urls)
            isImporting = false
            // Files that arrived while this batch was running.
            startPending(in: context)
        }
    }

    // MARK: - Answers from the Name Conflict screen

    func resolveConflict(_ choice: ConflictChoice, applyToAll: Bool) {
        conflict = nil
        conflictContinuation?.resume(returning: (choice, applyToAll))
        conflictContinuation = nil
    }

    /// True if no current file on this device uses `name` (ignoring upper/lower case).
    func isNameAvailable(_ name: String) -> Bool {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return false }
        return !currentNames().contains { $0.caseInsensitiveCompare(wanted) == .orderedSame }
    }

    // MARK: - The import itself

    private func run(_ urls: [URL]) async {
        guard let context else { return }
        var result = Summary()

        // Storage space check before anything is added.
        let bytesNeeded = urls.reduce(Int64(0)) { $0 + fileSize(of: $1) }
        if !StorageCheck.hasRoom(forBytes: bytesNeeded) {
            spaceProblem = SpaceProblem(fileCount: urls.count, bytesNeeded: bytesNeeded)
            urls.forEach(removeIfInboxCopy)
            return
        }

        var standingChoice: ConflictChoice?   // from "Do this for all remaining conflicts"

        for (index, url) in urls.enumerated() {
            defer { removeIfInboxCopy(url) }

            guard let package = load(url) else {
                result.unreadable += 1
                continue
            }

            var name = package.manifest.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { name = "Untitled" }

            if !isNameAvailable(name) {
                let suggested = suggestedName(for: name)
                let choice: ConflictChoice
                if let standingChoice {
                    choice = standingChoice
                } else {
                    let (picked, applyToAll) = await askAboutConflict(Conflict(
                        incomingName: name,
                        suggestedName: suggested,
                        canApplyToAll: index < urls.count - 1
                    ))
                    choice = picked
                    if applyToAll {
                        switch picked {
                        case .useSuggested, .skip: standingChoice = picked
                        default: break
                        }
                    }
                }

                switch choice {
                case .useSuggested:
                    name = suggested
                case .useName(let typed):
                    name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
                case .skip:
                    result.skipped += 1
                    continue
                case .cancelTransfer:
                    // This file and every file after it are left out;
                    // files imported before this point stay.
                    result.skipped += urls.count - index
                    urls[(index + 1)...].forEach(removeIfInboxCopy)
                    summary = result
                    return
                }
            }

            insert(package, named: name, into: context)
            result.imported += 1
            await Task.yield()
        }
        summary = result
    }

    private func askAboutConflict(_ newConflict: Conflict) async -> (ConflictChoice, Bool) {
        await withCheckedContinuation { continuation in
            conflictContinuation = continuation
            conflict = newConflict
        }
    }

    /// Creates the file and its photos from a transfer file.
    private func insert(_ package: FilePackage.LoadedPackage, named name: String, into context: ModelContext) {
        let manifest = package.manifest

        // Keep the hidden ID so a later transfer can recognize this same file,
        // unless a file with that ID is already here (then this is a second copy).
        let idAlreadyUsed = fileExists(withID: manifest.uniqueID)

        let file = SubjectFile(
            name: name,
            latitude: manifest.latitude,
            longitude: manifest.longitude,
            locationDescription: manifest.locationDescription,
            fieldNotes: manifest.fieldNotes,
            illustrationNotes: manifest.illustrationNotes
        )
        file.uniqueID = idAlreadyUsed ? UUID() : manifest.uniqueID
        file.dateAdded = manifest.dateAdded
        file.lastChanged = manifest.lastChanged
        file.isReadOnly = manifest.transferKind == .readOnly
        context.insert(file)

        for entry in manifest.photos {
            let photo = AlbumPhoto(
                imageData: package.blob(offset: entry.imageOffset, length: entry.imageLength),
                thumbnailData: package.blob(offset: entry.thumbnailOffset, length: entry.thumbnailLength),
                date: entry.date,
                kind: AlbumKind(rawValue: entry.album) ?? .subject,
                sortIndex: entry.position
            )
            context.insert(photo)
            photo.file = file
        }
        try? context.save()
    }

    // MARK: - Helpers

    /// Reads a received file, downloading it from iCloud Drive first if needed.
    private func load(_ url: URL) -> FilePackage.LoadedPackage? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        var data: Data?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            data = try? Data(contentsOf: readURL)
        }
        guard let data else { return nil }
        return try? FilePackage.read(data)
    }

    private func fileSize(of url: URL) -> Int64 {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return Int64(size)
    }

    /// Files opened from another app arrive as a copy in the app's Inbox folder;
    /// remove that copy once it has been imported (or skipped).
    private func removeIfInboxCopy(_ url: URL) {
        if url.path.contains("/Documents/Inbox/") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Names of the files currently in the File List.
    private func currentNames() -> [String] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<SubjectFile>(predicate: #Predicate { $0.replacedDate == nil })
        return ((try? context.fetch(descriptor)) ?? []).map(\.name)
    }

    private func fileExists(withID id: UUID) -> Bool {
        guard let context else { return false }
        let descriptor = FetchDescriptor<SubjectFile>(predicate: #Predicate { $0.uniqueID == id })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// "Great Blue Heron (2)", or (3), (4)… — the first one not already taken.
    private func suggestedName(for name: String) -> String {
        var number = 2
        while !isNameAvailable("\(name) (\(number))") {
            number += 1
        }
        return "\(name) (\(number))"
    }
}
