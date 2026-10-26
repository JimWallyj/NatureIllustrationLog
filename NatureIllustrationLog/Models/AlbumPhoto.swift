import Foundation
import SwiftData

/// Which of a file's two photo albums a photo belongs to.
enum AlbumKind: String, Identifiable {
    case subject        // photos of the nature subject itself
    case illustration   // photos of the finished (or in-progress) illustration

    var id: String { rawValue }
}

/// One photo in a file's album, with its own date and its place in the album's order.
@Model
final class AlbumPhoto {
    /// The full-size photo, copied into the app's own storage.
    /// Removed (nil) when the file is offloaded to the Mac; the thumbnail stays.
    @Attribute(.externalStorage) var imageData: Data?

    /// A small copy (about 400 px on the long side) used by lists and grids so
    /// they scroll smoothly even when the full-size photos are large camera files.
    var thumbnailData: Data

    /// Auto-read from the photo's metadata when available, or entered by hand.
    var date: Date?

    var kindRaw: String

    /// Position within the album. The photo with the lowest number is "first"
    /// and is the one the File Screen and File List show.
    var sortIndex: Int

    var file: SubjectFile?

    init(imageData: Data, thumbnailData: Data, date: Date?, kind: AlbumKind, sortIndex: Int) {
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.date = date
        self.kindRaw = kind.rawValue
        self.sortIndex = sortIndex
    }

    var kind: AlbumKind { AlbumKind(rawValue: kindRaw) ?? .subject }
}
