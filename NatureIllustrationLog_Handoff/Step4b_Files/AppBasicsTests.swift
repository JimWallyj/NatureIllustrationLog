import Foundation
import SwiftData
import Testing
@testable import NatureIllustrationLog

/// Step 2 of the unit tests (spec Section 8): the six original-app tests.
/// Each test uses its own temporary, in-memory database.
@MainActor
struct AppBasicsTests {

    // MARK: - Helpers

    static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: SubjectFile.self, AlbumPhoto.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    static let day1 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    static let day2 = Date(timeIntervalSinceReferenceDate: 800_086_400)

    static func photo(_ byte: UInt8, date: Date?) -> PickedPhoto {
        PickedPhoto(
            data: Data(repeating: byte, count: 64),
            thumbnailData: Data(repeating: byte, count: 8),
            dateTaken: date
        )
    }

    /// Opens the same database again in a new context, the way the app
    /// sees it after being closed and reopened.
    static func reopen(_ context: ModelContext) -> ModelContext {
        ModelContext(context.container)
    }

    static func fetchFile(named name: String, in context: ModelContext) throws -> SubjectFile? {
        try context.fetch(FetchDescriptor<SubjectFile>(predicate: #Predicate { $0.name == name })).first
    }

    // MARK: - 1. Saving a file

    @Test("Creating and saving a file stores its name, notes, location, and photos with their dates")
    func savingStoresEverything() throws {
        let context = try Self.makeContext()
        let file = SubjectFile(
            name: "Great Blue Heron",
            latitude: 33.3567,
            longitude: -111.7457,
            locationDescription: "Gilbert, AZ",
            fieldNotes: "Seen at the pond at dawn.",
            illustrationNotes: "Watercolor, 9 x 12."
        )
        context.insert(file)
        file.appendPhotos([Self.photo(1, date: Self.day1), Self.photo(2, date: Self.day2)], kind: .subject, in: context)
        file.appendPhotos([Self.photo(3, date: Self.day2)], kind: .illustration, in: context)
        try context.save()

        let reopened = Self.reopen(context)
        let saved = try #require(try Self.fetchFile(named: "Great Blue Heron", in: reopened))
        #expect(saved.fieldNotes == "Seen at the pond at dawn.")
        #expect(saved.illustrationNotes == "Watercolor, 9 x 12.")
        #expect(saved.latitude == 33.3567)
        #expect(saved.longitude == -111.7457)
        #expect(saved.locationDescription == "Gilbert, AZ")
        #expect(saved.album(.subject).map(\.date) == [Self.day1, Self.day2])
        #expect(saved.album(.subject).map(\.imageData) == [Data(repeating: 1, count: 64), Data(repeating: 2, count: 64)])
        #expect(saved.album(.illustration).map(\.date) == [Self.day2])
    }

    // MARK: - 2. Missing date or location

    @Test("A file with no photo date and no location saves and reloads correctly")
    func missingDateAndLocation() throws {
        let context = try Self.makeContext()
        let file = SubjectFile(name: "Unknown Sparrow", latitude: nil, longitude: nil, locationDescription: nil)
        context.insert(file)
        file.appendPhotos([Self.photo(5, date: nil)], kind: .subject, in: context)
        try context.save()

        let reopened = Self.reopen(context)
        let saved = try #require(try Self.fetchFile(named: "Unknown Sparrow", in: reopened))
        #expect(saved.latitude == nil)
        #expect(saved.longitude == nil)
        #expect(saved.locationDescription == nil)
        #expect(saved.album(.subject).count == 1)
        #expect(saved.album(.subject).first?.date == nil)
    }

    // MARK: - 3. File List order

    @Test("The File List sorts names alphabetically")
    func fileListIsAlphabetical() throws {
        let context = try Self.makeContext()
        for name in ["Oriole", "Bird 2", "Hummingbird", "Bird 1", "Irises"] {
            context.insert(SubjectFile(name: name, latitude: nil, longitude: nil, locationDescription: nil))
        }
        try context.save()

        let names = try context.fetch(FetchDescriptor<SubjectFile>(sortBy: SubjectFile.listOrder)).map(\.name)
        #expect(names == ["Bird 1", "Bird 2", "Hummingbird", "Irises", "Oriole"])
    }

    // MARK: - 4. Deleting a file

    @Test("Deleting a file removes it and its photos")
    func deletingRemovesPhotos() throws {
        let context = try Self.makeContext()
        let keep = SubjectFile(name: "Keep", latitude: nil, longitude: nil, locationDescription: nil)
        let remove = SubjectFile(name: "Remove", latitude: nil, longitude: nil, locationDescription: nil)
        context.insert(keep)
        context.insert(remove)
        keep.appendPhotos([Self.photo(1, date: nil)], kind: .subject, in: context)
        remove.appendPhotos([Self.photo(2, date: nil), Self.photo(3, date: nil)], kind: .subject, in: context)
        remove.appendPhotos([Self.photo(4, date: nil)], kind: .illustration, in: context)
        try context.save()

        context.delete(remove)
        try context.save()

        let names = try context.fetch(FetchDescriptor<SubjectFile>()).map(\.name)
        #expect(names == ["Keep"])
        #expect(try context.fetchCount(FetchDescriptor<AlbumPhoto>()) == 1)
    }

    // MARK: - 5. Album order and Set as First

    @Test("An album returns its photos in order, and Set as First changes which photo is first")
    func albumOrderAndSetAsFirst() throws {
        let context = try Self.makeContext()
        let file = SubjectFile(name: "Heron", latitude: nil, longitude: nil, locationDescription: nil)
        context.insert(file)
        file.appendPhotos([Self.photo(1, date: nil), Self.photo(2, date: nil), Self.photo(3, date: nil)], kind: .subject, in: context)
        file.appendPhotos([Self.photo(9, date: nil)], kind: .illustration, in: context)
        try context.save()

        // Photos come back in the order they were added.
        #expect(file.album(.subject).map { $0.thumbnailData.first } == [1, 2, 3])
        #expect(file.coverPhoto?.thumbnailData.first == 1)

        // Set the third photo as first.
        let third = file.album(.subject)[2]
        file.setAsFirst(third)
        try context.save()
        #expect(file.album(.subject).map { $0.thumbnailData.first } == [3, 1, 2])
        #expect(file.coverPhoto?.thumbnailData.first == 3)

        // The other album is not affected.
        #expect(file.illustrationCoverPhoto?.thumbnailData.first == 9)
    }

    // MARK: - 6. Home background

    @Test("Saving a Home background returns a filename, the image loads back, and the old one is removed")
    func homeBackgroundSaves() throws {
        let first = Data([0xFF, 0xD8, 0x01, 0x02])
        let second = Data([0xFF, 0xD8, 0x03, 0x04])

        let firstName = try #require(HomeBackgroundStore.replace(first, previousFilename: nil))
        defer { try? FileManager.default.removeItem(at: HomeBackgroundStore.url(for: firstName)) }
        #expect(try Data(contentsOf: HomeBackgroundStore.url(for: firstName)) == first)

        // Filenames are made from the time in seconds; wait so the next one differs.
        Thread.sleep(forTimeInterval: 1.1)

        let secondName = try #require(HomeBackgroundStore.replace(second, previousFilename: firstName))
        defer { try? FileManager.default.removeItem(at: HomeBackgroundStore.url(for: secondName)) }
        #expect(secondName != firstName)
        #expect(try Data(contentsOf: HomeBackgroundStore.url(for: secondName)) == second)
        #expect(!FileManager.default.fileExists(atPath: HomeBackgroundStore.url(for: firstName).path))
    }
}
