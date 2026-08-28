import Foundation

/// The finished story returned by any engine tier. Identical shape whether it
/// came from Apple's on-device model, the proxy API, or the template engine —
/// so the UI never needs to know which tier produced it.
struct BrokenBoneStory: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var story: String
    /// Short one-liner versions for texting / quick brags.
    var oneLiners: [String]
    /// Which tier generated this, for a small badge in the UI.
    var source: EngineSource

    init(
        id: UUID = UUID(),
        title: String,
        story: String,
        oneLiners: [String],
        source: EngineSource
    ) {
        self.id = id
        self.title = title
        self.story = story
        self.oneLiners = oneLiners
        self.source = source
    }
}

/// Which generation tier produced a story.
enum EngineSource: String, Codable, Hashable {
    case appleIntelligence = "On-device AI"
    case proxyGemini = "Cloud AI (Gemini)"
    case proxyGroq = "Cloud AI (Groq)"
    case template = "Classic"

    var badgeSymbol: String {
        switch self {
        case .appleIntelligence: return "apple.intelligence"
        case .proxyGemini, .proxyGroq: return "cloud.fill"
        case .template: return "shuffle"
        }
    }
}
