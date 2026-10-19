import Foundation

/// Checks for free space before the app stores a lot of new data at once
/// (importing files now; adding photos and restoring files in a later step).
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

    /// e.g. "1.4 GB", in the device's language.
    static func formatted(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
