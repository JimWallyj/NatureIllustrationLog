import Foundation
import SwiftData

/// A single nature subject entry: its photo albums plus the illustrator's notes.
@Model
final class SubjectFile {
    var name: String

    /// Date this entry was created in the app.
    var dateAdded: Date

    /// Location pinned by the user on the map.
    var latitude: Double?
    var longitude: Double?

    /// A short, human-readable location string (e.g. "Sedona, AZ") produced
    /// by reverse-geocoding latitude/longitude at pin time.
    var locationDescription: String?

    var fieldNotes: String
    var illustrationNotes: String

    // MARK: - Transfer support (hidden; never shown on screen)

    /// Permanent hidden ID, created once and never changed. Lets an import tell
    /// an updated copy of this same file from a different file with the same name.
    var uniqueID: UUID = UUID()

    /// When the notes, photos, photo dates, or location last changed.
    /// Shown in the Update warning when a file comes back from another device.
    var lastChanged: Date = Date.now

    /// True for files received from another person through "Share Read-Only".
    var isReadOnly: Bool = false

    /// True after the file is offloaded to the Mac: the full-size photos are
    /// removed and only thumbnails, notes, dates, and location remain.
    var isPlaceholder: Bool = false

    /// Set when this file was replaced by Update. Such files appear only in
    /// Recently Replaced and are deleted 30 days after this date.
    var replacedDate: Date?

    /// Both albums live here, told apart by each photo's `kind`.
    /// Deleting a file deletes its photos too.
    @Relationship(deleteRule: .cascade, inverse: \AlbumPhoto.file)
    var photos: [AlbumPhoto] = []

    init(
        name: String,
        latitude: Double?,
        longitude: Double?,
        locationDescription: String?,
        fieldNotes: String = "",
        illustrationNotes: String = ""
    ) {
        self.name = name
        self.dateAdded = .now
        self.latitude = latitude
        self.longitude = longitude
        self.locationDescription = locationDescription
        self.fieldNotes = fieldNotes
        self.illustrationNotes = illustrationNotes
        self.uniqueID = UUID()
        self.lastChanged = .now
    }

    /// Records that the user changed something in this file.
    func touch() {
        lastChanged = .now
    }

    /// The photos of one album, in order (first photo first).
    func album(_ kind: AlbumKind) -> [AlbumPhoto] {
        photos
            .filter { $0.kindRaw == kind.rawValue }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    /// The first subject photo — what the File Screen and File List show.
    var coverPhoto: AlbumPhoto? { album(.subject).first }

    /// The first illustration photo.
    var illustrationCoverPhoto: AlbumPhoto? { album(.illustration).first }

    /// Adds newly picked photos to the end of an album.
    func appendPhotos(_ picked: [PickedPhoto], kind: AlbumKind, in context: ModelContext) {
        var next = (album(kind).last?.sortIndex ?? -1) + 1
        for item in picked {
            let photo = AlbumPhoto(
                imageData: item.data,
                thumbnailData: item.thumbnailData,
                date: item.dateTaken,
                kind: kind,
                sortIndex: next
            )
            next += 1
            context.insert(photo)
            photo.file = self
        }
        touch()
    }
}
