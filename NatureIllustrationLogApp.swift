import SwiftData
import SwiftUI

@main
struct NatureIllustrationLogApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: SubjectFile.self)
    }
}
