import Foundation
import SwiftData
import UniformTypeIdentifiers

extension UTType {
    /// The app's own transfer file type (".natlog"), registered in the target's Info settings.
    static let natureLogFile = UTType(exportedAs: "com.walejko.NatureIllustrationLog.file")
}

/// The transfer file: one per Subject File, holding everything needed to
/// recreate it on another device — its hidden ID, name, notes, location,
/// dates, and every photo (full size and thumbnail) with its album, order,
/// and date. Transfer files use the extension ".natlog".
///
/// Layout (one plain file, built with Apple's own frameworks only):
///   1. An 8-byte marker, "NATLOG01", so the app can recognize its own files
///   2. 8 bytes giving the length of the description that follows
///   3. The description (`Manifest`), as JSON
///   4. The photo data, one after another. The description records where
///      each photo starts and how long it is.
enum FilePackage {
    static let fileExtension = "natlog"
    static let marker = Data("NATLOG01".utf8)
    static let formatVersion = 1

    /// How the receiving device should treat the file.
    enum TransferKind: String, Codable {
        case ownDevices   // "Send to My Devices": arrives editable
        case readOnly     // "Share Read-Only": arrives locked
    }

    struct PhotoEntry: Codable {
        var album: String          // AlbumKind raw value
        var position: Int          // 0 = first photo in its album
        var date: Date?
        var imageOffset: Int
        var imageLength: Int
        var thumbnailOffset: Int
        var thumbnailLength: Int
    }

    struct Manifest: Codable {
        var formatVersion: Int
        var transferKind: TransferKind
        var uniqueID: UUID
        var name: String
        var dateAdded: Date
        var lastChanged: Date
        var latitude: Double?
        var longitude: Double?
        var locationDescription: String?
        var fieldNotes: String
        var illustrationNotes: String
        var photos: [PhotoEntry]
    }

    enum PackageError: Error {
        case couldNotCreateFile
        case notAPackage      // not one of this app's transfer files
        case newerVersion     // made by a newer version of the app
        case damaged          // the file is incomplete or corrupted
    }

    /// A transfer file that has been read and checked, ready to import.
    struct LoadedPackage {
        let manifest: Manifest
        let data: Data
        let blobStart: Int

        /// One photo's bytes (full size or thumbnail).
        func blob(offset: Int, length: Int) -> Data {
            Data(data[(blobStart + offset)..<(blobStart + offset + length)])
        }
    }

    /// Reads and checks a transfer file. Throws if it isn't one of this app's
    /// files, was made by a newer version, or is damaged.
    static func read(_ data: Data) throws -> LoadedPackage {
        guard data.count >= 16, data.prefix(8) == marker else {
            throw PackageError.notAPackage
        }
        let length = data.subdata(in: 8..<16)
            .withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
            .littleEndian
        guard length <= UInt64(data.count - 16) else {
            throw PackageError.damaged
        }
        let blobStart = 16 + Int(length)

        let manifest: Manifest
        do {
            manifest = try JSONDecoder().decode(Manifest.self, from: data.subdata(in: 16..<blobStart))
        } catch {
            throw PackageError.damaged
        }
        guard manifest.formatVersion <= formatVersion else {
            throw PackageError.newerVersion
        }

        // Every photo must lie entirely inside the file.
        let blobBytes = data.count - blobStart
        for entry in manifest.photos {
            let pieces = [(entry.imageOffset, entry.imageLength), (entry.thumbnailOffset, entry.thumbnailLength)]
            for (offset, length) in pieces {
                guard offset >= 0, length >= 0, offset + length <= blobBytes else {
                    throw PackageError.damaged
                }
            }
        }
        return LoadedPackage(manifest: manifest, data: data, blobStart: blobStart)
    }

    /// A new, empty folder in the app's temporary area to hold one batch of exports.
    static func makeExportFolder() throws -> URL {
        removeOldExportFolders()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Deletes temporary export folders more than an hour old. Exports are not
    /// deleted when the share window closes, because on the Mac AirDrop and Mail
    /// read the file only after the share window has closed.
    static func removeOldExportFolders(olderThan age: TimeInterval = 3600) {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory
        guard let items = try? fm.contentsOfDirectory(
            at: temp, includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        for item in items where item.lastPathComponent.hasPrefix("Export-") {
            let created = (try? item.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            if Date.now.timeIntervalSince(created) > age {
                try? fm.removeItem(at: item)
            }
        }
    }

    /// Writes one file's package into `folder` and returns its location.
    static func write(_ file: SubjectFile, kind: TransferKind, to folder: URL) throws -> URL {
        var blobs: [Data] = []
        var entries: [PhotoEntry] = []
        var offset = 0

        for album in [AlbumKind.subject, AlbumKind.illustration] {
            for (position, photo) in file.album(album).enumerated() {
                // A placeholder has no full photo; it isn't sent, but fall back safely.
                let image = photo.imageData ?? photo.thumbnailData
                let thumbnail = photo.thumbnailData
                entries.append(PhotoEntry(
                    album: album.rawValue,
                    position: position,
                    date: photo.date,
                    imageOffset: offset,
                    imageLength: image.count,
                    thumbnailOffset: offset + image.count,
                    thumbnailLength: thumbnail.count
                ))
                offset += image.count + thumbnail.count
                blobs.append(image)
                blobs.append(thumbnail)
            }
        }

        let manifest = Manifest(
            formatVersion: formatVersion,
            transferKind: kind,
            uniqueID: file.uniqueID,
            name: file.name,
            dateAdded: file.dateAdded,
            lastChanged: file.lastChanged,
            latitude: file.latitude,
            longitude: file.longitude,
            locationDescription: file.locationDescription,
            fieldNotes: file.fieldNotes,
            illustrationNotes: file.illustrationNotes,
            photos: entries
        )
        let manifestData = try JSONEncoder().encode(manifest)

        let url = uniqueURL(for: file.name, in: folder)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw PackageError.couldNotCreateFile
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        try handle.write(contentsOf: marker)
        var length = UInt64(manifestData.count).littleEndian
        try handle.write(contentsOf: withUnsafeBytes(of: &length) { Data($0) })
        try handle.write(contentsOf: manifestData)
        for blob in blobs {
            try handle.write(contentsOf: blob)
        }
        return url
    }

    /// "Great Blue Heron.natlog", with characters that can't be in a file name
    /// replaced, and a number added if that name is already used in the folder.
    private static func uniqueURL(for name: String, in folder: URL) -> URL {
        var base = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "Untitled" }

        var candidate = folder.appendingPathComponent(base).appendingPathExtension(fileExtension)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(counter)").appendingPathExtension(fileExtension)
            counter += 1
        }
        return candidate
    }
}
