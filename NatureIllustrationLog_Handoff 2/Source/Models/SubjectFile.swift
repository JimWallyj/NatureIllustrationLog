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
    }
}
