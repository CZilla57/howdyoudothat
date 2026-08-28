import Foundation
import SwiftData

/// A story the user chose to keep, persisted with SwiftData.
@Model
final class SavedStory {
    var id: UUID
    var title: String
    var storyText: String
    var oneLiners: [String]
    var sourceRaw: String
    var createdAt: Date

    // Echo of the request, so the Library can show context.
    var boneRaw: String
    var location: String
    var activity: String

    init(story: BrokenBoneStory, request: StoryRequest, createdAt: Date = .now) {
        self.id = story.id
        self.title = story.title
        self.storyText = story.story
        self.oneLiners = story.oneLiners
        self.sourceRaw = story.source.rawValue
        self.createdAt = createdAt
        self.boneRaw = request.boneSummary
        self.location = request.location
        self.activity = request.activity
    }

    var source: EngineSource {
        EngineSource(rawValue: sourceRaw) ?? .template
    }

    /// Rebuild the value type for sharing / re-display.
    var asStory: BrokenBoneStory {
        BrokenBoneStory(id: id, title: title, story: storyText, oneLiners: oneLiners, source: source)
    }

    /// Nicely formatted block for the share sheet.
    var shareText: String {
        var lines = ["\(title)\n", storyText]
        if let first = oneLiners.first {
            lines.append("\n— or, the short version: \(first)")
        }
        return lines.joined(separator: "\n")
    }
}
