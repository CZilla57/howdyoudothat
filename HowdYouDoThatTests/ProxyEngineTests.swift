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
        {"title":"T","story":"S","oneLiners":["a","b"],"source":"groq"}
        """)
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        let result = try await engine.makeStory(for: request)
        #expect(result.title == "T")
        #expect(result.story == "S")
        #expect(result.oneLiners == ["a", "b"])
        #expect(result.source == .proxyGroq)
    }

    @Test("Maps the Gemini source and caps one-liners at three")
    func mapsGeminiAndCapsOneLiners() async throws {
        respond(status: 200, json: """
        {"title":"T","story":"S","oneLiners":["1","2","3","4","5"],"source":"gemini"}
        """)
        let engine = ProxyEngine(endpoint: endpoint, session: stubbedSession())
        let result = try await engine.makeStory(for: request)
        #expect(result.source == .proxyGemini)
        #expect(result.oneLiners.count == 3)
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
