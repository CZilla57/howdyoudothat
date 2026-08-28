import Foundation

/// Anything that can turn a `StoryRequest` into a `BrokenBoneStory`.
/// The Apple, proxy, and template engines all conform, which lets the
/// resolver treat them uniformly and fall back tier to tier.
protocol StoryEngine: Sendable {
    /// Whether this engine is usable on the current device/session right now.
    func isAvailable() async -> Bool

    /// Produce a story, or throw so the resolver can drop to the next tier.
    func makeStory(for request: StoryRequest) async throws -> BrokenBoneStory
}

enum StoryEngineError: LocalizedError {
    case unavailable
    case emptyResult
    case timedOut
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "This story engine isn't available."
        case .emptyResult: return "The story came back empty."
        case .timedOut: return "The story engine took too long."
        case .underlying(let message): return message
        }
    }
}
