import SwiftUI

enum Route: Hashable {
    case fileList
}

/// Shared navigation path for the app's single NavigationStack, so the
/// "Home" button on any screen (File List, File Detail) can pop straight
/// back to the root regardless of how deep it is.
@Observable
final class NavigationCoordinator {
    var path = NavigationPath()

    func goHome() {
        path = NavigationPath()
    }

    func showFileList() {
        path.append(Route.fileList)
    }
}
