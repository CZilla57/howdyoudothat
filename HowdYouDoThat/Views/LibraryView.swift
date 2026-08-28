import SwiftUI
import SwiftData

/// Saved stories, newest first. Tap to read, swipe to delete, share inline.
struct LibraryView: View {
    @Query(sort: \SavedStory.createdAt, order: .reverse) private var stories: [SavedStory]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if stories.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(stories) { story in
                        NavigationLink {
                            SavedStoryDetail(story: story)
                        } label: {
                            row(story)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Saved")
        .toolbar {
            if !stories.isEmpty {
                EditButton()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("🦴")
                .font(.system(size: 60))
            Text("No stories yet")
                .font(.title3.bold())
            Text("Head to the Create tab, spin up a story, and tap Save — your greatest hits live here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ story: SavedStory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(story.title)
                .font(.headline)
                .lineLimit(1)
            Text("\(story.boneRaw) · \(story.location)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(story.storyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(stories[index])
        }
        try? modelContext.save()
    }
}

/// Full read view for a saved story.
struct SavedStoryDetail: View {
    let story: SavedStory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(story.title)
                    .font(.title2.bold())
                Text("\(story.boneRaw) · \(story.location)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(story.storyText)
                    .font(.body)
                    .lineSpacing(4)

                if !story.oneLiners.isEmpty {
                    Divider()
                    Text("Short versions")
                        .font(.headline)
                    ForEach(story.oneLiners, id: \.self) { line in
                        Text("• \(line)")
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: story.shareText)
        }
    }
}

#Preview {
    NavigationStack { LibraryView() }
        .modelContainer(for: SavedStory.self, inMemory: true)
}
