import Foundation

/// A bone the user can say they broke. `rawValue` is the display name.
enum Bone: String, CaseIterable, Codable, Identifiable, Hashable {
    case wrist = "Wrist"
    case ankle = "Ankle"
    case collarbone = "Collarbone"
    case finger = "Finger"
    case toe = "Toe"
    case arm = "Arm"
    case leg = "Leg"
    case rib = "Rib"
    case nose = "Nose"
    case foot = "Foot"
    case hand = "Hand"
    case kneecap = "Kneecap"
    case elbow = "Elbow"
    case jaw = "Jaw"
    case tailbone = "Tailbone"

    var id: String { rawValue }

    /// An SF Symbol that loosely evokes the body part, for the picker.
    var symbolName: String {
        switch self {
        case .wrist, .hand, .finger: return "hand.raised.fill"
        case .ankle, .foot, .toe: return "shoeprints.fill"
        case .leg, .kneecap: return "figure.walk"
        case .arm, .elbow: return "figure.arms.open"
        case .collarbone, .rib: return "lungs.fill"
        case .nose, .jaw: return "face.smiling"
        case .tailbone: return "figure.seated.side"
        }
    }
}
