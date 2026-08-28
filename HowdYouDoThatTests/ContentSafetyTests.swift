import Testing
@testable import HowdYouDoThat

@Suite("ContentSafety")
struct ContentSafetyTests {

    @Test("Ordinary broken-bone input is allowed")
    func allowsNormalInput() {
        #expect(ContentSafety.isDisallowed("Colorado") == false)
        #expect(ContentSafety.isDisallowed("attempting a backflip off a curb") == false)
        #expect(ContentSafety.isDisallowed("my grandma's damn porch") == false) // mild swearing is fine
    }

    @Test("Innocent substrings don't trip the word filter")
    func noFalsePositives() {
        // Words that merely *contain* a blocked fragment must pass.
        #expect(ContentSafety.isDisallowed("assist the class with the assignment") == false)
        #expect(ContentSafety.isDisallowed("scrape my knee") == false)
        #expect(ContentSafety.isDisallowed("cumulative document") == false)
    }

    @Test("Explicit and slur content is blocked")
    func blocksDisallowed() {
        #expect(ContentSafety.isDisallowed("something rape something") == true)
        #expect(ContentSafety.isDisallowed("watching porn") == true)
        #expect(ContentSafety.isDisallowed("leetspeak n1gger bypass") == true)
    }

    @Test("Any-of helper flags a collection containing bad text")
    func flagsCollections() {
        #expect(ContentSafety.isDisallowed(any: ["clean", "also clean"]) == false)
        #expect(ContentSafety.isDisallowed(any: ["clean", "incest joke"]) == true)
    }
}
