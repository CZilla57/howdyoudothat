import Foundation
import FoundationModels

/// Tier 1: Apple's on-device Foundation Models.
///
/// Free, private, and fully offline. When the system language model is
/// available we ask it for a structured `GeneratedStory` via guided
/// generation, then map that onto the app's `BrokenBoneStory`. When the model
/// is unavailable (unsupported device, Apple Intelligence off, model still
/// downloading, etc.) we report `isAvailable() == false` so the resolver
/// cleanly drops to the proxy and then the template tier.
struct AppleIntelligenceEngine: StoryEngine {

    /// The on-device model, resolved once. Reading `.availability` is cheap.
    private let model = SystemLanguageModel.default

    /// How long we let the on-device model run before giving up and dropping to
    /// the proxy tier. On-device generation is usually a few seconds, but a cold
    /// model or a stall can hang far longer — we'd rather fall through than make
    /// the user stare at the spinner.
    private static let responseTimeout: Duration = .seconds(12)

    func isAvailable() async -> Bool {
        model.availability == .available
    }

    func makeStory(for request: StoryRequest) async throws -> BrokenBoneStory {
        // Guard again in case availability changed since the resolver checked.
        guard model.availability == .available else {
            throw StoryEngineError.unavailable
        }

        let session = LanguageModelSession(model: model) {
            Self.instructions(for: request)
        }

        let prompt = Self.prompt(for: request)
        let generated: GeneratedStory
        do {
            generated = try await withThrowingTaskGroup(of: GeneratedStory.self) { group in
                group.addTask {
                    let response = try await session.respond(
                        to: prompt,
                        generating: GeneratedStory.self
                    )
                    return response.content
                }
                group.addTask {
                    try await Task.sleep(for: Self.responseTimeout)
                    throw StoryEngineError.timedOut
                }
                // Whichever finishes first wins; cancel the loser (the sleep, or
                // the in-flight generation on timeout).
                defer { group.cancelAll() }
                guard let first = try await group.next() else {
                    throw StoryEngineError.emptyResult
                }
                return first
            }
        } catch let error as StoryEngineError {
            throw error
        } catch {
            throw StoryEngineError.underlying(error.localizedDescription)
        }

        let title = generated.title.trimmed
        let story = generated.story.trimmed
        guard !title.isEmpty, !story.isEmpty else {
            throw StoryEngineError.emptyResult
        }

        let oneLiners = generated.oneLiners
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

        return BrokenBoneStory(
            title: title,
            story: story,
            oneLiners: Array(oneLiners.prefix(3)),
            source: .appleIntelligence
        )
    }

    // MARK: - Prompting

    /// System instructions: the persona and hard rules that hold across the
    /// whole session, independent of the specific request.
    private static func instructions(for request: StoryRequest) -> String {
        """
        You help someone tell the story of how they broke a bone the way they'd \
        actually say it out loud to a friend — like a quick voice memo, not a \
        written paragraph.

        How it should sound:
        - Start in the middle, the way people really do: "So I'm at the park, right, \
        and…" — never with a title-drop, a "Picture it," or any scene-setting.
        - Real talk: contractions, filler like "honestly," "I'm not gonna lie," "so," \
        "anyway," and the odd half-finished thought or self-correction. It's fine to \
        trail off or double back.
        - The humor is in the shrug — how casually you drop the ridiculous part — not \
        in clever wording.
        - Let it ramble a little. A perfectly structured beginning-middle-end sounds \
        written; a real retelling wanders.

        Hard rules:
        - First person, casual, as the person who broke the bone.
        - 3–4 short sentences, about the length of a quick story at a bar.
        - The tone you're given is a FLAVOR on how you talk, not a costume: lean into \
        that attitude in your word choice, but you're still just a person telling a \
        friend what happened — never slip into narrator, announcer, or podcast-host voice.
        - No literary or blog-style writing: no scene-setting openers, no metaphors or \
        similes ("like a popcorn kernel"), no dramatic narration. If it reads like a \
        short story, say it plainer.
        - Keep it PG-13. No graphic gore, no slurs, nothing sexual, no real \
        medical advice.
        - Never invent a different bone, place, or activity than the ones given.

        The vibe to aim for (don't reuse this text): "Okay so I'm barely off the couch, \
        right, and my ankle just — went. Didn't trip, didn't fall, nothing. One second \
        I'm walking to the kitchen, next thing I know I'm on the floor googling whether \
        you can hear your own bone break. Turns out: yeah."
        """
    }

    /// The per-request prompt describing exactly this break.
    private static func prompt(for request: StoryRequest) -> String {
        let place = request.location.trimmed.isEmpty
            ? "an unnamed location" : request.location.trimmed
        let activity = request.activity.trimmed.isEmpty
            ? "doing something forgettable" : request.activity.trimmed

        var lines = [
            "Tell the story of how I broke my \(request.bonePhrase), the way I'd say it out loud to a friend.",
            "Where it happened: \(place).",
            "What I was actually doing: \(activity).",
            "Flavor to lean into: \(request.tone.rawValue) — \(request.tone.direction). Keep it a flavor on how you talk, not a performance.",
            "Cheekiness level: \(Self.spiceGuidance(request.spiceLevel)).",
        ]

        if !request.audience.trimmed.isEmpty {
            lines.append("Write it to impress: \(request.audience.trimmed).")
        }
        if request.embellish {
            lines.append("Work in one absurd celebrity or animal cameo.")
        }

        lines.append(
            "Also give up to 3 one-line versions I could text to a friend."
        )
        return lines.joined(separator: "\n")
    }

    private static func spiceGuidance(_ level: StoryRequest.SpiceLevel) -> String {
        switch level {
        case .clean:  return "squeaky clean and wholesome"
        case .cheeky: return "cheeky and playful, but still tame"
        case .wild:   return "maximally cheeky and over-the-top, still PG-13"
        }
    }
}

/// The structured shape we ask the on-device model to fill in. Guided
/// generation constrains the model to exactly these fields, so we never have
/// to parse free-form text.
@Generable
private struct GeneratedStory {
    @Guide(description: "A short, casual, funny title — how you'd label the story in a text, max 8 words.")
    var title: String

    @Guide(description: "The story like a quick voice memo to a friend: 3 to 4 short, spoken-sounding first-person sentences. Can start mid-thought and ramble a little. Casual and funny, never announcer/narrator/blog voice.")
    var story: String

    @Guide(description: "Exactly 3 one-line versions you could text a friend, each under 20 words and sounding like something you'd actually type.")
    var oneLiners: [String]
}
