import Foundation
import ImageIO
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// How album photos are stored: at most 4096 pixels on the longest side, in
/// HEIC (about half the size of JPEG at the same quality). If a device can't
/// create HEIC, the photo is saved as JPEG instead. Thumbnails (about 400 px,
/// JPEG) are made separately and are not affected.
enum PhotoStorage {
    nonisolated static let maxPixelSize = 4096
    nonisolated static let quality = 0.85

    /// Stored data for a newly picked photo (Photos Library picker).
    nonisolated static func storedData(from image: UIImage) -> Data? {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        let longest = max(width, height)
        guard longest > 0 else { return nil }
        let factor = min(1, CGFloat(maxPixelSize) / longest)
        let target = CGSize(width: (width * factor).rounded(), height: (height * factor).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let cgImage = resized.cgImage else { return nil }
        return encode(cgImage)
    }

    /// HEIC, or JPEG if HEIC isn't available on this device.
    nonisolated static func encode(_ cgImage: CGImage) -> Data? {
        for type in [UTType.heic, UTType.jpeg] {
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else {
                continue
            }
            let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
            if CGImageDestinationFinalize(destination), output.length > 0 {
                return output as Data
            }
        }
        return nil
    }

    /// For "Optimize Photo Storage": a smaller copy of an already stored photo,
    /// or nil when it is already optimized (HEIC and within 4096 px) or when
    /// the new copy wouldn't be smaller.
    nonisolated static func optimizedData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let isHEIC = (CGImageSourceGetType(source) as String?) == UTType.heic.identifier
        if isHEIC && max(width, height) <= maxPixelSize {
            return nil
        }

        // Turned upright and limited to 4096 px on the long side.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let smaller = encode(cgImage),
              smaller.count < data.count else { return nil }
        return smaller
    }

    struct OptimizeResult {
        var photosChanged = 0
        var bytesSaved: Int64 = 0
    }

    /// Shrinks every stored full-size photo on this device, one at a time.
    /// `progress(done, total)` is called after each photo. Files' "last
    /// changed" dates are not touched: the photos look the same.
    static func optimizeAll(in context: ModelContext, progress: (Int, Int) -> Void) async -> OptimizeResult {
        var result = OptimizeResult()
        let photos = ((try? context.fetch(FetchDescriptor<AlbumPhoto>())) ?? [])
        let total = photos.count
        for (index, photo) in photos.enumerated() {
            if let data = photo.imageData {
                let smaller = await Task.detached(priority: .userInitiated) {
                    PhotoStorage.optimizedData(from: data)
                }.value
                if let smaller {
                    photo.imageData = smaller
                    result.photosChanged += 1
                    result.bytesSaved += Int64(data.count - smaller.count)
                    if result.photosChanged % 10 == 0 {
                        try? context.save()
                    }
                }
            }
            progress(index + 1, total)
        }
        try? context.save()
        return result
    }
}
