import SwiftUI

/// Top-level tabs: create a new story, or browse saved ones.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Create", systemImage: "wand.and.stars") {
                NavigationStack {
                    InputView()
                }
            }
            Tab("Saved", systemImage: "books.vertical.fill") {
                NavigationStack {
                    LibraryView()
                }
            }
        }
        .tint(.accentColor)
    }
}

#Preview {
    RootView()
        .modelContainer(for: SavedStory.self, inMemory: true)
}
