import Foundation

/// Treat model output as untrusted data. A structurally valid JSON response can
/// still be too long, leak field labels into the prose, or ignore the user's
/// facts. Invalid AI output is rejected so the resolver can use the next tier.
enum StoryOutputValidator {
    private static let maxTitleLength = 80
    private static let maxStoryLength = 900
    private static let maxOneLinerLength = 160
    private static let structuralMarkers = [
        #"\bone[\s-]?liners?\s*:"#,
        #"\bshort versions?\s*:"#,
        #"```"#,
    ]
    private static let ignoredGroundingWords: Set<String> = [
        "a", "an", "and", "at", "in", "of", "on", "the", "to", "was", "were",
        "doing", "trying", "actually", "some", "something",
    ]

    static func validatedStory(
        title rawTitle: String,
        story rawStory: String,
        oneLiners rawOneLiners: [String],
        source: EngineSource,
        request: StoryRequest
    ) throws -> BrokenBoneStory {
        let title = rawTitle.trimmed
        let story = rawStory.trimmed
        let oneLiners = rawOneLiners.map(\.trimmed).filter { !$0.isEmpty }

        guard
            !title.isEmpty,
            !story.isEmpty,
            title.count <= maxTitleLength,
            story.count <= maxStoryLength,
            oneLiners.count == 3,
            oneLiners.allSatisfy({ $0.count <= maxOneLinerLength }),
            Set(oneLiners.map { $0.lowercased() }).count == oneLiners.count,
            !containsStructuralMarker(title),
            !containsStructuralMarker(story),
            isGrounded(title: title, story: story, request: request)
        else {
            throw StoryEngineError.emptyResult
        }

        return BrokenBoneStory(
            title: title,
            story: story,
            oneLiners: oneLiners,
            source: source
        )
    }

    private static func containsStructuralMarker(_ text: String) -> Bool {
        structuralMarkers.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func isGrounded(title: String, story: String, request: StoryRequest) -> Bool {
        let outputTokens = Set(tokens(in: "\(title) \(story)"))
        let boneTokens = request.orderedBones.flatMap { tokens(in: $0.rawValue) }

        guard boneTokens.allSatisfy(outputTokens.contains) else { return false }
        return overlaps(outputTokens, input: request.location)
            && overlaps(outputTokens, input: request.activity)
    }

    private static func overlaps(_ outputTokens: Set<String>, input: String) -> Bool {
        let candidates = tokens(in: input).filter {
            $0.count >= 3 && !ignoredGroundingWords.contains($0)
        }
        // Very short inputs such as "gym" still produce a candidate. If a user
        // enters only stop words, don't reject an otherwise valid response.
        return candidates.isEmpty || candidates.contains(where: outputTokens.contains)
    }

    private static func tokens(in text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }
}
