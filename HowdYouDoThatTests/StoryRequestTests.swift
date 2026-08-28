import Testing
@testable import HowdYouDoThat

@Suite("StoryRequest")
struct StoryRequestTests {

    @Test("Needs both location and activity before it's ready")
    func readinessRequiresBothFields() {
        #expect(StoryRequest(location: "", activity: "").isReadyToGenerate == false)
        #expect(StoryRequest(location: "Ohio", activity: "").isReadyToGenerate == false)
        #expect(StoryRequest(location: "", activity: "a backflip").isReadyToGenerate == false)
        #expect(StoryRequest(location: "Ohio", activity: "a backflip").isReadyToGenerate == true)
    }

    @Test("Whitespace-only fields don't count as filled in")
    func whitespaceIsNotReady() {
        #expect(StoryRequest(location: "   ", activity: "\n\t").isReadyToGenerate == false)
    }

    @Test("Spiciness maps to the right bucket, including boundaries")
    func spiceLevelBuckets() {
        #expect(StoryRequest(spiciness: 0.0).spiceLevel == .clean)
        #expect(StoryRequest(spiciness: 0.33).spiceLevel == .clean)
        #expect(StoryRequest(spiciness: 0.34).spiceLevel == .cheeky)
        #expect(StoryRequest(spiciness: 0.5).spiceLevel == .cheeky)
        #expect(StoryRequest(spiciness: 0.66).spiceLevel == .cheeky)
        #expect(StoryRequest(spiciness: 0.67).spiceLevel == .wild)
        #expect(StoryRequest(spiciness: 1.0).spiceLevel == .wild)
    }
}
