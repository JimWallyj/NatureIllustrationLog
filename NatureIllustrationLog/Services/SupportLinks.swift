import Foundation
import UIKit

/// Web addresses for help, hosted on GitHub Pages (repository
/// "jimwallyj.github.io"). These are built into the app, so the pages must
/// keep these addresses — don't rename the repository or the folder.
enum SupportLinks {
    /// The support page: contact email, common questions, and a link to the
    /// User Manual (PDF).
    static let help = URL(string: "https://jimwallyj.github.io/nature-illustration-log/support.html")!

    /// Opens the support page in the browser (Safari, or the Mac's default browser).
    @MainActor
    static func openHelp() {
        UIApplication.shared.open(help)
    }
}
