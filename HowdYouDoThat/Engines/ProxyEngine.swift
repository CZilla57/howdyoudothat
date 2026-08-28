import Foundation

/// Tier 2: the free Cloudflare Worker proxy (Gemini first, then Groq).
///
/// The app POSTs the story inputs to the Worker as JSON; the Worker races
/// Gemini (with a timeout) then Groq server-side and returns a finished story,
/// or signals "use a template" — in which case we throw so the resolver drops
/// to the on-device `TemplateEngine`. The endpoint comes from `AppConfig`
/// (Info.plist), so the tier stays off until a Worker URL is configured.
struct ProxyEngine: StoryEngine {

    let endpoint: URL?
    private let session: URLSession
    /// Overall client-side budget; the Worker has its own per-model timeouts.
    private let timeout: TimeInterval

    init(endpoint: URL? = nil, session: URLSession = .shared, timeout: TimeInterval = 20) {
        self.endpoint = endpoint
        self.session = session
        self.timeout = timeout
    }

    func isAvailable() async -> Bool {
        endpoint != nil
    }

    func makeStory(for request: StoryRequest) async throws -> BrokenBoneStory {
        guard let endpoint else { throw StoryEngineError.unavailable }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = timeout
        urlRequest.httpBody = try JSONEncoder().encode(ProxyRequestBody(request))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .timedOut {
            throw StoryEngineError.timedOut
        } catch {
            throw StoryEngineError.underlying(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw StoryEngineError.underlying("Non-HTTP response from proxy.")
        }
        // 204 = Worker explicitly asked us to fall back to a template.
        guard http.statusCode != 204 else { throw StoryEngineError.emptyResult }
        guard (200...299).contains(http.statusCode) else {
            throw StoryEngineError.underlying("Proxy returned HTTP \(http.statusCode).")
        }

        let body: ProxyResponseBody
        do {
            body = try JSONDecoder().decode(ProxyResponseBody.self, from: data)
        } catch {
            throw StoryEngineError.underlying("Could not decode proxy response.")
        }

        // The Worker can also signal fallback in-band.
        if body.fallbackToTemplate == true {
            throw StoryEngineError.emptyResult
        }

        let title = body.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let story = body.story?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty, !story.isEmpty else { throw StoryEngineError.emptyResult }

        let oneLiners = (body.oneLiners ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return BrokenBoneStory(
            title: title,
            story: story,
            oneLiners: Array(oneLiners.prefix(3)),
            source: body.engineSource
        )
    }
}

// MARK: - Wire format

/// What the app sends to the Worker. An explicit, stable shape (rather than
/// encoding `StoryRequest` directly) so the Worker contract doesn't shift if
/// the app's internal model changes.
private struct ProxyRequestBody: Encodable {
    let bone: String
    let location: String
    let activity: String
    let tone: String
    let toneDirection: String
    let spiciness: Double
    let spiceLevel: String
    let audience: String
    let embellish: Bool

    init(_ r: StoryRequest) {
        bone = r.bonePhrase
        location = r.location.trimmed
        activity = r.activity.trimmed
        tone = r.tone.rawValue
        toneDirection = r.tone.direction
        spiciness = r.spiciness
        spiceLevel = switch r.spiceLevel {
        case .clean: "clean"
        case .cheeky: "cheeky"
        case .wild: "wild"
        }
        audience = r.audience.trimmed
        embellish = r.embellish
    }
}

/// What the Worker returns. All fields optional so a partial / fallback
/// response decodes cleanly and we can validate explicitly.
private struct ProxyResponseBody: Decodable {
    let title: String?
    let story: String?
    let oneLiners: [String]?
    /// "gemini" or "groq"; anything else maps to a generic cloud badge.
    let source: String?
    let fallbackToTemplate: Bool?

    var engineSource: EngineSource {
        switch source?.lowercased() {
        case "groq": return .proxyGroq
        default:     return .proxyGemini
        }
    }
}
