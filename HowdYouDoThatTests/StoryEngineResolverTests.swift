import Testing
@testable import HowdYouDoThat

/// A configurable stand-in engine so we can script availability and success
/// per tier and assert exactly how the resolver walks the fallback chain.
private struct MockEngine: StoryEngine {
    var available = true
    var story: BrokenBoneStory? = nil
    var throwsError = false

    func isAvailable() async -> Bool { available }

    func makeStory(for request: StoryRequest) async throws -> BrokenBoneStory {
        if throwsError { throw StoryEngineError.underlying("mock failure") }
        guard let story else { throw StoryEngineError.emptyResult }
        return story
    }
}

private func story(_ title: String, source: EngineSource) -> BrokenBoneStory {
    BrokenBoneStory(title: title, story: "body", oneLiners: ["one"], source: source)
}

private let sampleRequest = StoryRequest(
    bones: [.wrist], location: "here", activity: "there", tone: .absurd
)

@Suite("StoryEngineResolver fallback chain")
struct StoryEngineResolverTests {

    @Test("Uses the first available engine that succeeds")
    func firstAvailableWins() async {
        let resolver = StoryEngineResolver(tiers: [
            MockEngine(available: true, story: story("A", source: .appleIntelligence)),
            MockEngine(available: true, story: story("B", source: .proxyGroq)),
        ])
        let result = await resolver.makeStory(for: sampleRequest)
        #expect(result.title == "A")
        #expect(result.source == .appleIntelligence)
    }

    @Test("Skips an unavailable tier and uses the next available one")
    func skipsUnavailable() async {
        let resolver = StoryEngineResolver(tiers: [
            MockEngine(available: false, story: story("A", source: .appleIntelligence)),
            MockEngine(available: true, story: story("B", source: .proxyGroq)),
        ])
        let result = await resolver.makeStory(for: sampleRequest)
        #expect(result.title == "B")
        #expect(result.source == .proxyGroq)
    }

    @Test("Falls through when an available tier throws")
    func fallsThroughOnThrow() async {
        let resolver = StoryEngineResolver(tiers: [
            MockEngine(available: true, throwsError: true),
            MockEngine(available: true, story: story("B", source: .proxyGemini)),
        ])
        let result = await resolver.makeStory(for: sampleRequest)
        #expect(result.title == "B")
        #expect(result.source == .proxyGemini)
    }

    @Test("Falls back to a template story when every tier fails")
    func templateFallbackWhenAllFail() async {
        let resolver = StoryEngineResolver(tiers: [
            MockEngine(available: false),
            MockEngine(available: true, throwsError: true),
        ])
        let result = await resolver.makeStory(for: sampleRequest)
        // The resolver's defensive final path always produces a template story.
        #expect(result.source == .template)
        #expect(!result.title.isEmpty)
        #expect(!result.story.isEmpty)
    }

    @Test("Real default resolver never throws and always returns a story")
    func defaultResolverAlwaysReturns() async {
        // No proxy endpoint injected → Apple tier unavailable on a test host and
        // proxy unavailable, so this exercises the real template guarantee.
        let resolver = StoryEngineResolver(proxyEndpoint: nil)
        let result = await resolver.makeStory(for: sampleRequest)
        #expect(!result.story.isEmpty)
    }
}
