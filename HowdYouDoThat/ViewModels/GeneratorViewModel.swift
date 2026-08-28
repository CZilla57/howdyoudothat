import Foundation
import Observation

/// Drives the input → result flow. Holds the working request, the current
/// story, and the generation state. Engine-agnostic: it only talks to the
/// resolver, which handles the fallback chain.
@MainActor
@Observable
final class GeneratorViewModel {
    var request = StoryRequest()
    var phase: Phase = .idle

    /// Every story generated this session, oldest first. Reroll / Wilder append
    /// here instead of overwriting, so the user can flip back to one they liked.
    private(set) var history: [BrokenBoneStory] = []
    /// Which entry in `history` is currently on screen.
    private(set) var historyIndex = 0

    private let resolver: StoryEngineResolver

    init(resolver: StoryEngineResolver = StoryEngineResolver()) {
        self.resolver = resolver
    }

    enum Phase: Equatable {
        case idle
        case generating
        case done
        case failed(String)
    }

    var isGenerating: Bool { phase == .generating }

    /// The story currently being shown — the entry `historyIndex` points at.
    var story: BrokenBoneStory? {
        history.indices.contains(historyIndex) ? history[historyIndex] : nil
    }

    // MARK: History navigation

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex < history.count - 1 }
    /// 1-based position for display, e.g. "2 of 3".
    var historyPosition: Int { history.isEmpty ? 0 : historyIndex + 1 }
    var historyCount: Int { history.count }

    func showPrevious() {
        guard canGoBack else { return }
        historyIndex -= 1
    }

    func showNext() {
        guard canGoForward else { return }
        historyIndex += 1
    }

    // MARK: Generation

    /// Generate a story from the current request and append it to history.
    func generate() async {
        guard request.isReadyToGenerate else { return }

        // Input moderation: don't even generate from disallowed prompts.
        if ContentSafety.isDisallowed(any: [request.location, request.activity, request.audience]) {
            phase = .failed("Let's keep it PG-13 — try rewording that and give it another go.")
            return
        }

        phase = .generating
        var result = await resolver.makeStory(for: request)

        // Output moderation: if a tier slipped something through, fall back to
        // the always-clean template engine (which only uses the vetted input).
        if ContentSafety.isDisallowed(any: [result.title, result.story] + result.oneLiners) {
            var rng = SystemRandomNumberGenerator()
            result = TemplateEngine.build(from: request, using: &rng)
        }

        history.append(result)
        historyIndex = history.count - 1
        phase = .done
    }

    /// Same inputs, new roll of the dice.
    func regenerate() async {
        await generate()
    }

    /// Nudge spiciness up and regenerate — the "Make it wilder" button.
    func makeItWilder() async {
        request.spiciness = min(1.0, request.spiciness + 0.25)
        await generate()
    }

    /// Reset to a blank slate for a brand-new story.
    func startOver() {
        request = StoryRequest()
        history = []
        historyIndex = 0
        phase = .idle
    }
}
