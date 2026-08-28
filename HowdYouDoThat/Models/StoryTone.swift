import Foundation

/// The overall flavor the generated story should take on.
enum StoryTone: String, CaseIterable, Codable, Identifiable, Hashable {
    case absurd = "Absurd"
    case heroic = "Heroic"
    case dramatic = "Dramatic"
    case mysterious = "Mysterious"
    case wholesome = "Wholesome"
    case conspiracy = "Conspiracy"
    case fairytale = "Fairytale"
    case sportscast = "Sportscast"
    case corporate = "Corporate"
    case trueCrime = "True Crime"
    case western = "Western"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .absurd: return "🤪"
        case .heroic: return "🦸"
        case .dramatic: return "🎭"
        case .mysterious: return "🕵️"
        case .wholesome: return "🥰"
        case .conspiracy: return "🛸"
        case .fairytale: return "🧚"
        case .sportscast: return "🎙️"
        case .corporate: return "💼"
        case .trueCrime: return "🔪"
        case .western: return "🤠"
        }
    }

    /// A short hint shown under the chip and fed to AI engines later.
    var direction: String {
        switch self {
        case .absurd: return "gloriously ridiculous and over-the-top"
        case .heroic: return "brave, epic, and self-aggrandizing"
        case .dramatic: return "theatrical and full of suspense"
        case .mysterious: return "cryptic, noir, and vaguely unexplained"
        case .wholesome: return "sweet, silly, and feel-good"
        case .conspiracy: return "paranoid, over-explained, and definitely a cover-up"
        case .fairytale: return "whimsical, once-upon-a-time, and storybook enchanted"
        case .sportscast: return "breathless, play-by-play sports commentary"
        case .corporate: return "buzzword-laden corporate-speak, like a LinkedIn post"
        case .trueCrime: return "ominous true-crime podcast narration, grave and suspenseful"
        case .western: return "dusty old-west tall tale, drawled around a campfire"
        }
    }
}
