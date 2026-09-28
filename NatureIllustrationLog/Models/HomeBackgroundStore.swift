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
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let filename = "home-background-\(Int(Date().timeIntervalSince1970)).jpg"
        do {
            try data.write(to: url(for: filename))
            return filename
        } catch {
            return nil
        }
    }
}
