import SwiftUI
import SwiftData

@main
struct HowdYouDoThatApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: SavedStory.self)
    }
}
