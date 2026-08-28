import Foundation
import Testing
@testable import HowdYouDoThat

/// Intercepts URLSession traffic so ProxyEngine can be tested against canned
/// Worker responses with no network. The responder is set per test; the suite
/// is serialized so the shared hook isn't raced.
private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responder: ((URLRequest) -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = Self.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = responder(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data { client?.urlProtocol(self, didLoad: data) }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private let endpoint = URL(string: "https://example.com/story")!

private func stubbedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

private func respond(status: Int, json: String?) {
    StubURLProtocol.responder = { request in
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        return (response, json.map { Data($0.utf8) })
    }
}

private let request = StoryRequest(
    bones: [.wrist], location: "Ohio", activity: "a backflip", tone: .absurd
)

@Suite("ProxyEngine", .serialized)
struct ProxyEngineTests {

    @Test("Is unavailable without an endpoint, available with one")
    func availability() async {
        #expect(await ProxyEngine(endpoint: nil).isAvailable() == false)
        #expect(await ProxyEngine(endpoint: endpoint).isAvailable() == true)
    }

    @Test("Decodes a 200 response and maps the Groq source")
    func decodesGroqSuccess() async throws {
        respond(status: 200, json: """
        {"title":"Wrist Trouble","story":"So I was doing a backflip in Ohio and broke my wrist.","oneLiners":["Ohio won.","The backflip won.","My wrist lost."],"source":"groq"}
        """)
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        let result = try await engine.makeStory(for: request)
        #expect(result.title == "Wrist Trouble")
        #expect(result.oneLiners.count == 3)
        #expect(result.source == .proxyGroq)
    }

    @Test("Maps the Gemini source with exactly three one-liners")
    func mapsGeminiWithThreeOneLiners() async throws {
        respond(status: 200, json: """
        {"title":"Ohio Wrist","story":"My wrist met the floor during a backflip in Ohio.","oneLiners":["one","two","three"],"source":"gemini"}
        """)
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        let result = try await engine.makeStory(for: request)
        #expect(result.source == .proxyGemini)
        #expect(result.oneLiners.count == 3)
    }

    @Test("Rejects malformed structure that leaked into the story")
    func rejectsLeakedOneLiners() async {
        respond(status: 200, json: """
        {"title":"Ohio Wrist","story":"I broke my wrist doing a backflip in Ohio. OneLiners: nope","oneLiners":["one","two","three"],"source":"groq"}
        """)
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        await #expect(throws: StoryEngineError.self) {
            _ = try await engine.makeStory(for: request)
        }
    }

    @Test("Rejects a story that ignores the supplied facts")
    func rejectsUngroundedStory() async {
        respond(status: 200, json: """
        {"title":"Beach Trouble","story":"I hurt my ankle surfing in California.","oneLiners":["one","two","three"],"source":"groq"}
        """)
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        await #expect(throws: StoryEngineError.self) {
            _ = try await engine.makeStory(for: request)
        }
    }

    @Test("Throws on a 204 fallback signal")
    func throwsOn204() async {
        respond(status: 204, json: nil)
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        await #expect(throws: StoryEngineError.self) {
            _ = try await engine.makeStory(for: request)
        }
    }

    @Test("Throws when the body asks for a template fallback")
    func throwsOnInBandFallback() async {
        respond(status: 200, json: #"{"fallbackToTemplate":true}"#)
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        await #expect(throws: StoryEngineError.self) {
            _ = try await engine.makeStory(for: request)
        }
    }

    @Test("Throws when required fields are missing")
    func throwsOnEmptyFields() async {
        respond(status: 200, json: #"{"title":"","story":"","oneLiners":[]}"#)
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        await #expect(throws: StoryEngineError.self) {
            _ = try await engine.makeStory(for: request)
        }
    }

    @Test("Throws on malformed JSON")
    func throwsOnMalformedJSON() async {
        respond(status: 200, json: "not json at all")
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        await #expect(throws: StoryEngineError.self) {
            _ = try await engine.makeStory(for: request)
        }
    }

    @Test("Throws on a server error status")
    func throwsOnServerError() async {
        respond(status: 500, json: #"{"error":"boom"}"#)
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        await #expect(throws: StoryEngineError.self) {
            _ = try await engine.makeStory(for: request)
        }
    }
}
