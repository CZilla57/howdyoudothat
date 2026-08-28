import Testing
@testable import HowdYouDoThat

/// A deterministic RNG so template assembly is reproducible in tests.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        // SplitMix64.
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@Suite("TemplateEngine")
struct TemplateEngineTests {

    private let request = StoryRequest(
        bones: [.ankle],
        location: "Barcelona",
        activity: "salsa dancing",
        tone: .dramatic,
        spiciness: 0.5
    )

    @Test("Always produces a non-empty story tagged as the template source")
    func producesNonEmptyTemplateStory() async throws {
        let result = try await TemplateEngine().makeStory(for: request)
        #expect(result.source == .template)
        #expect(!result.title.isEmpty)
        #expect(!result.story.isEmpty)
        #expect(result.oneLiners.count <= 3)
    }

    @Test("Is deterministic for a fixed seed")
    func deterministicForSeed() {
        var rngA = SeededGenerator(seed: 42)
        var rngB = SeededGenerator(seed: 42)
        let a = TemplateEngine.build(from: request, using: &rngA)
        let b = TemplateEngine.build(from: request, using: &rngB)
        #expect(a.title == b.title)
        #expect(a.story == b.story)
        #expect(a.oneLiners == b.oneLiners)
    }

    @Test("Substitutes the user's location and activity into the prose")
    func fillsInUserInputs() {
        var rng = SeededGenerator(seed: 7)
        let result = TemplateEngine.build(from: request, using: &rng)
        // Placeholders are replaced with the real place/activity somewhere.
        #expect(result.story.contains("Barcelona") || result.story.contains("salsa dancing"))
    }

    @Test("Falls back to placeholder text when inputs are blank")
    func handlesBlankInputs() {
        var rng = SeededGenerator(seed: 1)
        let blank = StoryRequest(bones: [.rib], location: "", activity: "", tone: .absurd)
        let result = TemplateEngine.build(from: blank, using: &rng)
        #expect(!result.story.isEmpty)
    }
}
