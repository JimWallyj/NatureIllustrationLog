import Foundation
import ImageIO
import UIKit

/// Turns image files chosen with "Files" into album photos, the same way the
/// Photos Library picker does: a full-size JPEG, a small (~400 px) thumbnail,
/// and the date taken, read from the file's own camera information (EXIF)
/// when it has one — e.g. Lumix JPEGs. Camera RAW files are converted to JPEG.
enum ImageFileLoader {
    /// Loads the files one at a time, in the order chosen. Files that aren't
    /// readable images are skipped.
    static func loadPhotos(from urls: [URL]) async -> [PickedPhoto] {
        var photos: [PickedPhoto] = []
        for url in urls {
            if let photo = loadPhoto(from: url) {
                photos.append(photo)
            }
            await Task.yield()   // keep the progress indicator moving
        }
        return photos
    }

    private static func loadPhoto(from url: URL) -> PickedPhoto? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        // Downloads the file from iCloud Drive first if needed.
        var data: Data?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            data = try? Data(contentsOf: readURL)
        }
        guard let data,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }

        // Full image, turned upright, limited to 8192 px on the long side.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 8192
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        guard let full = image.jpegData(compressionQuality: 0.9) else { return nil }

        return PickedPhoto(
            data: full,
            thumbnailData: thumbnailData(for: image) ?? full,
            dateTaken: dateTaken(from: source)
        )
    }

    /// A small JPEG (about 400 px on the long side) for lists and grids.
    private static func thumbnailData(for image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, 400 / longest)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let thumbnail = image.preparingThumbnail(of: target) ?? image
        return thumbnail.jpegData(compressionQuality: 0.8)
    }

    /// The date the photo was taken, from the camera information inside the file.
    private static func dateTaken(from source: CGImageSource) -> Date? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let text = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? (exif?[kCGImagePropertyExifDateTimeDigitized] as? String)
            ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String)
        guard let text else { return nil }
        return exifDateFormatter.date(from: text)
    }

    /// Camera dates look like "2018:03:29 14:05:12", in the camera's local time.
    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter
    }()
}
