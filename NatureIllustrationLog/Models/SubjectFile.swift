import Foundation
import SwiftData

/// A single nature subject entry: the photo plus the illustrator's notes.
@Model
final class SubjectFile {
    var name: String

    /// The photo, copied into the app's own storage so it survives even if
    /// the original is later deleted from the user's Photos library.
    @Attribute(.externalStorage) var photoData: Data

    /// Date the photo was originally taken, read from the Photos asset if available.
    var dateTaken: Date?

    /// Date this entry was created in the app.
    var dateAdded: Date

    /// Location read from the photo's metadata, if present.
    var latitude: Double?
    var longitude: Double?

    /// A short, human-readable location string (e.g. "Sedona, AZ") produced
    /// by reverse-geocoding latitude/longitude at import time.
    var locationDescription: String?

    var fieldNotes: String
    var illustrationNotes: String

    /// The finished (or in-progress) illustration photo, added later from the
    /// File Screen — separate from the original nature-subject photo above.
    @Attribute(.externalStorage) var illustrationPhotoData: Data?
    var illustrationPhotoDate: Date?

    init(
        name: String,
        photoData: Data,
        dateTaken: Date?,
        latitude: Double?,
        longitude: Double?,
        locationDescription: String?,
        fieldNotes: String = "",
        illustrationNotes: String = "",
        illustrationPhotoData: Data? = nil,
        illustrationPhotoDate: Date? = nil
    ) {
        self.name = name
        self.photoData = photoData
        self.dateTaken = dateTaken
        self.dateAdded = .now
        self.latitude = latitude
        self.longitude = longitude
        self.locationDescription = locationDescription
        self.fieldNotes = fieldNotes
        self.illustrationNotes = illustrationNotes
        self.illustrationPhotoData = illustrationPhotoData
        self.illustrationPhotoDate = illustrationPhotoDate
    }
}
