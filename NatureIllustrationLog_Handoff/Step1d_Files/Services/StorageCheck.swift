import Foundation

/// Checks for free space before the app stores a lot of new data at once
/// (importing files and adding photos).
enum StorageCheck {
    /// Whether the device has room for `bytes` more, with a 10% safety margin.
    /// If the free space can't be read, the operation is allowed to go ahead.
    static func hasRoom(forBytes bytes: Int64) -> Bool {
        guard let free = freeBytes() else { return true }
        return Double(bytes) * 1.1 < Double(free)
    }

    /// Free space available for important data such as the user's files.
    static func freeBytes() -> Int64? {
        let values = try? URL.homeDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    /// Total size of picked photos (full size plus thumbnails).
    static func bytes(of photos: [PickedPhoto]) -> Int64 {
        photos.reduce(Int64(0)) { $0 + Int64($1.data.count + $1.thumbnailData.count) }
    }

    /// e.g. "1.4 GB", in the device's language.
    static func formatted(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
