import SwiftData
import SwiftUI

@main
struct NatureIllustrationLogApp: App {
    @State private var menuCommands = MenuCommands()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(menuCommands)
        }
        .modelContainer(for: [SubjectFile.self, AlbumPhoto.self])
        // Mac menu bar (File menu). The shortcuts also work on an iPad with a keyboard.
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File") {
                    menuCommands.newFileRequested = true
                }
                .keyboardShortcut("n")

                Button("Import Files…") {
                    menuCommands.importRequested = true
                }
                .keyboardShortcut("i")
            }
        }
    }
}

/// Requests from the menu bar, picked up by the Home screen.
@Observable
final class MenuCommands {
    var newFileRequested = false
    var importRequested = false
}
