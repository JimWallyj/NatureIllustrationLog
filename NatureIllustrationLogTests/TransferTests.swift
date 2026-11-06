import Foundation
import SwiftData
import Testing
@testable import NatureIllustrationLog

/// Step 1 of the unit tests (spec Section 8): the four transfer tests.
/// Every test uses its own temporary, in-memory database, so nothing on the
/// device is read or changed.
@MainActor
struct TransferTests {

    // MARK: - Helpers

    /// A fresh, empty, in-memory database — like a separate device.
    static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: SubjectFile.self, AlbumPhoto.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Fixed dates (whole seconds) so comparisons are exact.
    static let day1 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let day2 = Date(timeIntervalSinceReferenceDate: 800_086_400)
    static let day3 = Date(timeIntervalSinceReferenceDate: 800_172_800)

    /// A file with two subject photos (the second without a date), one
    /// illustration photo, notes, and a location.
    static func makeSampleFile(named name: String, in context: ModelContext) -> SubjectFile {
        let file = SubjectFile(
            name: name,
            latitude: 33.3567,
            longitude: -111.7457,
            locationDescription: "Gilbert, AZ",
            fieldNotes: "Seen at the pond at dawn.",
            illustrationNotes: "Watercolor, 9 x 12."
        )
        file.dateAdded = day1
        file.lastChanged = day2
        context.insert(file)

        let photos: [(AlbumKind, Int, Date?, UInt8)] = [
            (.subject, 0, day1, 10),
            (.subject, 1, nil, 20),
            (.illustration, 0, day3, 30),
        ]
        for (kind, index, date, byte) in photos {
            let photo = AlbumPhoto(
                imageData: Data(repeating: byte, count: 64),
                thumbnailData: Data(repeating: byte + 1, count: 8),
                date: date,
                kind: kind,
                sortIndex: index
            )
            context.insert(photo)
            photo.file = file
        }
        try? context.save()
        return file
    }

    /// Exports a file to a transfer file and reads it back, as the receiving device would.
    static func exportAndRead(_ file: SubjectFile, kind: FilePackage.TransferKind = .ownDevices) throws -> FilePackage.LoadedPackage {
        let folder = try FilePackage.makeExportFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try FilePackage.write(file, kind: kind, to: folder)
        return try FilePackage.read(Data(contentsOf: url))
    }

    /// Files shown in the File List (not in Recently Replaced).
    static func currentFiles(in context: ModelContext) throws -> [SubjectFile] {
        try context.fetch(FetchDescriptor<SubjectFile>(predicate: #Predicate { $0.replacedDate == nil }))
    }

    /// Files in Recently Replaced.
    static func replacedFiles(in context: ModelContext) throws -> [SubjectFile] {
        try context.fetch(FetchDescriptor<SubjectFile>(predicate: #Predicate { $0.replacedDate != nil }))
    }

    // MARK: - 1. Export and import keep everything

    @Test("A file exported and imported again keeps its hidden ID, name, notes, location, photos, dates, and order")
    func exportImportRoundTrip() throws {
        let sending = try Self.makeContext()
        let original = Self.makeSampleFile(named: "Great Blue Heron", in: sending)
        let package = try Self.exportAndRead(original)

        let receiving = try Self.makeContext()   // the other device
        ImportManager.insert(package, named: package.manifest.name, into: receiving)

        let files = try Self.currentFiles(in: receiving)
        try #require(files.count == 1)
        let copy = files[0]

        #expect(copy.uniqueID == original.uniqueID)
        #expect(copy.name == "Great Blue Heron")
        #expect(copy.fieldNotes == original.fieldNotes)
        #expect(copy.illustrationNotes == original.illustrationNotes)
        #expect(copy.latitude == original.latitude)
        #expect(copy.longitude == original.longitude)
        #expect(copy.locationDescription == original.locationDescription)
        #expect(copy.dateAdded == original.dateAdded)
        #expect(copy.lastChanged == original.lastChanged)
        #expect(copy.isReadOnly == false)
        #expect(copy.isPlaceholder == false)

        for kind in [AlbumKind.subject, AlbumKind.illustration] {
            let before = original.album(kind)
            let after = copy.album(kind)
            #expect(after.count == before.count)
            for (a, b) in zip(before, after) {
                #expect(b.imageData == a.imageData)
                #expect(b.thumbnailData == a.thumbnailData)
                #expect(b.date == a.date)
            }
        }
    }

    @Test("A file sent with Share Read-Only arrives locked")
    func readOnlyArrivesLocked() throws {
        let sending = try Self.makeContext()
        let original = Self.makeSampleFile(named: "Oriole", in: sending)
        let package = try Self.exportAndRead(original, kind: .readOnly)

        let receiving = try Self.makeContext()
        let copy = ImportManager.insert(package, named: package.manifest.name, into: receiving)

        #expect(copy.isReadOnly)
        #expect(copy.isLocked)
    }

    // MARK: - 2. Suggested names for a name conflict

    @Test("The suggested conflict name skips names already taken")
    func suggestedNameSkipsTakenNames() {
        #expect(ImportManager.suggestedName(for: "Heron", taken: ["Heron"]) == "Heron (2)")
        #expect(ImportManager.suggestedName(for: "Heron", taken: ["Heron", "Heron (2)"]) == "Heron (3)")
        // Upper/lower case doesn't matter.
        #expect(ImportManager.suggestedName(for: "Heron", taken: ["Heron", "heron (2)", "HERON (3)"]) == "Heron (4)")
        // A gap is filled: (2) is free even though (3) is taken.
        #expect(ImportManager.suggestedName(for: "Heron", taken: ["Heron", "Heron (3)"]) == "Heron (2)")
    }

    // MARK: - 3. Update and Recently Replaced

    @Test("Update moves the older version to Recently Replaced and the new copy keeps the hidden ID")
    func updateMovesOlderVersionToRecentlyReplaced() throws {
        let context = try Self.makeContext()
        let existing = Self.makeSampleFile(named: "Heron", in: context)
        let originalID = existing.uniqueID

        // The same file, changed on another device.
        let otherDevice = try Self.makeContext()
        let changed = Self.makeSampleFile(named: "Heron", in: otherDevice)
        changed.uniqueID = originalID
        changed.fieldNotes = "Updated on the Mac."
        changed.lastChanged = Self.day3
        let package = try Self.exportAndRead(changed)

        let outcome = ImportManager.applyUpdate(package, replacing: existing, named: "Heron", in: context)
        #expect(outcome == .updated)

        let current = try Self.currentFiles(in: context)
        try #require(current.count == 1)
        #expect(current[0].fieldNotes == "Updated on the Mac.")
        #expect(current[0].uniqueID == originalID)

        let replaced = try Self.replacedFiles(in: context)
        try #require(replaced.count == 1)
        #expect(replaced[0].fieldNotes == "Seen at the pond at dawn.")
        #expect(replaced[0].isLocked)
    }

    @Test("Versions older than 30 days are removed from Recently Replaced; newer ones stay")
    func expiredVersionsAreRemoved() throws {
        let context = try Self.makeContext()
        let old = Self.makeSampleFile(named: "Old Heron", in: context)
        let recent = Self.makeSampleFile(named: "Recent Heron", in: context)
        let current = Self.makeSampleFile(named: "Current Heron", in: context)
        old.replacedDate = Calendar.current.date(byAdding: .day, value: -31, to: .now)
        recent.replacedDate = Calendar.current.date(byAdding: .day, value: -29, to: .now)
        try context.save()

        RecentlyReplacedView.removeExpired(in: context)

        let names = Set(try context.fetch(FetchDescriptor<SubjectFile>()).map(\.name))
        #expect(names == ["Recent Heron", "Current Heron"])
        // The removed version's photos are deleted with it.
        let photoCount = try context.fetchCount(FetchDescriptor<AlbumPhoto>())
        #expect(photoCount == 6)
        _ = current
    }

    @Test("Update on a lightweight copy brings back the full file, with nothing left in Recently Replaced")
    func updateRestoresLightweightCopy() throws {
        let context = try Self.makeContext()
        let onIPhone = Self.makeSampleFile(named: "Heron", in: context)
        let originalID = onIPhone.uniqueID

        // The Mac still has the full file.
        let mac = try Self.makeContext()
        let full = Self.makeSampleFile(named: "Heron", in: mac)
        full.uniqueID = originalID
        let package = try Self.exportAndRead(full)

        onIPhone.freeUpFullPhotos()
        try context.save()

        let outcome = ImportManager.applyUpdate(package, replacing: onIPhone, named: "Heron", in: context)
        #expect(outcome == .restoredFromMac)

        let current = try Self.currentFiles(in: context)
        try #require(current.count == 1)
        #expect(current[0].isPlaceholder == false)
        #expect(current[0].uniqueID == originalID)
        #expect(current[0].photos.allSatisfy { $0.imageData != nil })
        #expect(try Self.replacedFiles(in: context).isEmpty)
    }

    // MARK: - 4. Offloading

    @Test("Offloading removes full-size photos and keeps thumbnails, notes, dates, and location")
    func offloadKeepsLightweightCopy() throws {
        let context = try Self.makeContext()
        let file = Self.makeSampleFile(named: "Heron", in: context)
        let thumbnailsBefore = file.photos.map(\.thumbnailData).sorted { $0.first ?? 0 < $1.first ?? 0 }
        let datesBefore = file.album(.subject).map(\.date) + file.album(.illustration).map(\.date)

        file.freeUpFullPhotos()
        try context.save()

        #expect(file.isPlaceholder)
        #expect(file.isLocked)
        #expect(file.photos.count == 3)
        #expect(file.photos.allSatisfy { $0.imageData == nil })
        #expect(file.photos.map(\.thumbnailData).sorted { $0.first ?? 0 < $1.first ?? 0 } == thumbnailsBefore)
        #expect(file.album(.subject).map(\.date) + file.album(.illustration).map(\.date) == datesBefore)
        #expect(file.fieldNotes == "Seen at the pond at dawn.")
        #expect(file.illustrationNotes == "Watercolor, 9 x 12.")
        #expect(file.latitude == 33.3567)
        #expect(file.longitude == -111.7457)
        #expect(file.locationDescription == "Gilbert, AZ")
        #expect(file.name == "Heron")
    }
}
