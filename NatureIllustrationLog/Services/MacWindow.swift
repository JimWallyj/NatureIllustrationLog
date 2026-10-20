import SwiftUI
import UIKit

/// Mac only: sets the window's smallest allowed size, and its starting size
/// (about 1100 × 800) the first time the app opens. After that, the Mac
/// remembers whatever size and position the user chooses.
enum MacWindow {
    static func configure() {
        #if targetEnvironment(macCatalyst)
        let firstLaunchKey = "didSetInitialMacWindowSize"
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 700, height: 550)

            if !UserDefaults.standard.bool(forKey: firstLaunchKey) {
                UserDefaults.standard.set(true, forKey: firstLaunchKey)
                let frame = CGRect(x: 120, y: 80, width: 1100, height: 800)
                windowScene.requestGeometryUpdate(.Mac(systemFrame: frame))
            }
        }
        #endif
    }
}
