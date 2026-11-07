import Foundation
import ImageIO
import SwiftData
import Testing
import UIKit
@testable import NatureIllustrationLog

/// Smaller stored photos: at most 4096 px on the longest side, HEIC (or JPEG
/// where HEIC isn't available).
@MainActor
struct PhotoStorageTests {

    /// A test picture of the given size with some color variation.
    static func makeImage(width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        }
    }

    static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height)
    }

    @Test("A large new photo is stored at most 4096 pixels on the longest side, keeping its shape")
    func newPhotoIsResized() throws {
        let data = try #require(PhotoStorage.storedData(from: Self.makeImage(width: 6000, height: 4000)))
        let size = try #require(Self.pixelSize(of: data))
        #expect(size.width == 4096)
        #expect(size.height == 2731)
        #expect(UIImage(data: data) != nil)
    }

    @Test("A small new photo is not enlarged")
    func smallPhotoKeepsItsSize() throws {
        let data = try #require(PhotoStorage.storedData(from: Self.makeImage(width: 1200, height: 900)))
        let size = try #require(Self.pixelSize(of: data))
        #expect(size.width == 1200)
        #expect(size.height == 900)
    }

    @Test("Optimize shrinks a large stored JPEG and leaves an optimized photo alone")
    func optimizeShrinksOnlyLargePhotos() throws {
        let bigJPEG = try #require(Self.makeImage(width: 6000, height: 4000).jpegData(compressionQuality: 0.9))
        let smaller = try #require(PhotoStorage.optimizedData(from: bigJPEG))
        #expect(smaller.count < bigJPEG.count)
        let size = try #require(Self.pixelSize(of: smaller))
        #expect(max(size.width, size.height) == 4096)

        // Running it again on the result changes nothing (when HEIC is available).
        if let source = CGImageSourceCreateWithData(smaller as CFData, nil),
           (CGImageSourceGetType(source) as String?) == "public.heic" {
            #expect(PhotoStorage.optimizedData(from: smaller) == nil)
        }
    }

    @Test("Optimize Photo Storage updates stored photos and skips lightweight copies")
    func optimizeAllInDatabase() async throws {
        let container = try ModelContainer(
            for: SubjectFile.self, AlbumPhoto.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let file = SubjectFile(name: "Heron", latitude: nil, longitude: nil, locationDescription: nil)
        let lastChanged = file.lastChanged
        context.insert(file)
        let bigJPEG = try #require(Self.makeImage(width: 6000, height: 4000).jpegData(compressionQuality: 0.9))
        let big = AlbumPhoto(imageData: bigJPEG, thumbnailData: Data([1]), date: nil, kind: .subject, sortIndex: 0)
        let offloaded = AlbumPhoto(imageData: bigJPEG, thumbnailData: Data([2]), date: nil, kind: .subject, sortIndex: 1)
        context.insert(big)
        context.insert(offloaded)
        big.file = file
        offloaded.file = file
        offloaded.imageData = nil
        try context.save()

        var lastProgress = (0, 0)
        let result = await PhotoStorage.optimizeAll(in: context) { done, total in
            lastProgress = (done, total)
        }

        #expect(result.photosChanged == 1)
        #expect(result.bytesSaved > 0)
        #expect(lastProgress.0 == 2 && lastProgress.1 == 2)
        #expect((big.imageData?.count ?? .max) < bigJPEG.count)
        #expect(offloaded.imageData == nil)
        #expect(file.lastChanged == lastChanged)
    }
}
