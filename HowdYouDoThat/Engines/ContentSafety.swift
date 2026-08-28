import Foundation

/// Lightweight, on-device content moderation.
///
/// The generation prompts already ask every engine to stay PG-13, but that is a
/// *request*, not a guarantee — an LLM can still be steered somewhere ugly by
/// hostile input. This adds an actual gate on both ends:
///  - user input is screened before we generate, and
///  - generated output is screened before we show it,
/// falling back to the always-safe template engine if anything slips through.
///
/// The list is deliberately compact and stem-based; it catches the worst
/// categories (slurs, explicit sexual terms) without trying to be a profanity
/// nanny — mild swearing is fine for this app's voice.
enum ContentSafety {

    /// Substrings that disqualify text *anywhere* they appear. Only fragments
    /// that never occur inside an innocent English word live here — leetspeak
    /// slurs and unambiguous explicit compounds — so we avoid flagging
    /// "scrape", "cumulative", "assist", etc. (Plain short words like "rape" or
    /// "cum" are handled by the whole-word pass below instead.)
    private static let blockedStems: [String] = [
        // Leetspeak slur evasions.
        "n1gger", "n1gga", "f4ggot", "k1ke", "sp1c", "ch1nk", "tr4nny", "ret4rd",
        // Unambiguous explicit terms (no innocent word contains these).
        "pedophil", "bestial", "molest", "incest", "porn",
        "blowjob", "handjob", "deepthroat", "creampie", "cumshot",
    ]

    /// Terms that must match as a *standalone token*, so innocent substrings
    /// ("scrape" → "rape", "cumulative" → "cum") never trip the filter.
    private static let blockedWords: Set<String> = [
        "rape", "raped", "raping", "cum", "pedo",
        "nigger", "nigga", "faggot", "fag", "kike", "spic", "chink",
        "tranny", "retard", "retarded", "molested",
    ]

    /// True if the text contains disallowed content and should be blocked.
    static func isDisallowed(_ text: String) -> Bool {
        let lower = text.lowercased()

        // Token pass: split on non-letters and check exact word membership.
        let tokens = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        if tokens.contains(where: { blockedWords.contains($0) }) {
            return true
        }

        // Stem pass: catch leetspeak / compounded forms that survive tokenizing.
        for stem in blockedStems where lower.contains(stem) {
            return true
        }
        return false
    }

    /// Convenience: is this collection of strings clean?
    static func isDisallowed(any texts: [String]) -> Bool {
        texts.contains(where: isDisallowed)
    }
}
