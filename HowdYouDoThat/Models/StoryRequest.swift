import Foundation

/// Everything the user tells us, used by every engine tier to produce a story.
struct StoryRequest: Codable, Hashable {
    /// One or more bones the user says they broke.
    var bones: Set<Bone>
    var location: String
    var activity: String
    var tone: StoryTone
    /// 0 = squeaky clean, 1 = maximally cheeky. Kept PG-13 at the top end.
    var spiciness: Double
    /// Optional "who are you trying to impress?" character.
    var audience: String
    /// Add an absurd celebrity/animal cameo.
    var embellish: Bool

    init(
        bones: Set<Bone> = [.wrist],
        location: String = "",
        activity: String = "",
        tone: StoryTone = .absurd,
        spiciness: Double = 0.5,
        audience: String = "",
        embellish: Bool = false
    ) {
        self.bones = bones
        self.location = location
        self.activity = activity
        self.tone = tone
        self.spiciness = spiciness
        self.audience = audience
        self.embellish = embellish
    }

    /// The inputs we actually require before generating.
    var isReadyToGenerate: Bool {
        !bones.isEmpty && !location.trimmed.isEmpty && !activity.trimmed.isEmpty
    }

    /// Selected bones in a stable order (the order they appear in the picker).
    var orderedBones: [Bone] {
        Bone.allCases.filter { bones.contains($0) }
    }

    /// Grammatical, lowercased list of the broken bones for weaving into
    /// narrative prose, e.g. "wrist", "wrist and ankle", "wrist, ankle, and rib".
    var bonePhrase: String {
        let names = orderedBones.map { $0.rawValue.lowercased() }
        switch names.count {
        case 0: return "something"
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "\(head), and \(names.last ?? "")"
        }
    }

    /// Compact display label preserving the picker's casing, e.g. "Wrist, Ankle".
    var boneSummary: String {
        orderedBones.map(\.rawValue).joined(separator: ", ")
    }

    /// Human-readable spiciness bucket, also used by the template engine.
    var spiceLevel: SpiceLevel {
        switch spiciness {
        case ..<0.34: return .clean
        case ..<0.67: return .cheeky
        default: return .wild
        }
    }

    enum SpiceLevel { case clean, cheeky, wild }

    /// A fully randomized request for the "Surprise me" button — random bones,
    /// vibe, spiciness, and a made-up scene, so a story can be generated without
    /// filling in the form.
    static func random() -> StoryRequest {
        let boneCount = Int.random(in: 1...2)
        let bones = Set(Bone.allCases.shuffled().prefix(boneCount))
        return StoryRequest(
            bones: bones.isEmpty ? [.wrist] : bones,
            location: randomLocations.randomElement() ?? "somewhere questionable",
            activity: randomActivities.randomElement() ?? "doing something ill-advised",
            tone: StoryTone.allCases.randomElement() ?? .absurd,
            spiciness: Double.random(in: 0...1),
            audience: "",
            embellish: Bool.random()
        )
    }

    private static let randomLocations = [
        "a Waffle House parking lot",
        "the top of a bouncy castle",
        "aisle 7 of a hardware store",
        "a friend's wedding",
        "the world's saddest water park",
        "a corporate team-building retreat",
        "grandma's back porch",
        "a llama farm",
        "the DMV waiting room",
        "a haunted corn maze",
        "a very fancy grocery store",
        "the county fair"
    ]

    private static let randomActivities = [
        "reenacting a movie stunt",
        "chasing an ice cream truck",
        "winning an argument about physics",
        "showing off for absolutely no one",
        "escaping a very slow goose",
        "attempting the worm",
        "carrying way too many grocery bags at once",
        "trying to impress a barista",
        "doing a trust fall no one agreed to",
        "speedrunning the stairs",
        "helping move a couch",
        "settling a dare"
    ]
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Same string with only the first character upper-cased (leaves the rest
    /// alone, unlike `capitalized`).
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
