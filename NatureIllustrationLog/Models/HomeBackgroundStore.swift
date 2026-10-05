import Foundation
import UIKit

/// Stores the user-selected Home screen background image as a JPEG in the
/// app's Documents directory. Only the filename is kept in UserDefaults
/// (via @AppStorage in HomeView/EditHomeView) — the image itself lives on disk.
enum HomeBackgroundStore {
    static func url(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    @discardableResult
    private static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let filename = "home-background-\(Int(Date().timeIntervalSince1970)).jpg"
        do {
            try data.write(to: url(for: filename))
            return filename
        } catch {
            return nil
        }
    }

    /// Saves a new background and removes the previous one from disk, so old
    /// backgrounds don't accumulate every time the user changes it.
    @discardableResult
    static func replace(_ image: UIImage, previousFilename: String?) -> String? {
        guard let newFilename = save(image) else { return nil }
        if let previousFilename, !previousFilename.isEmpty {
            try? FileManager.default.removeItem(at: url(for: previousFilename))
        }
        return newFilename
    }
}
