import Foundation

/// Runs the fallback chain: Apple on-device AI → proxy (Gemini→Groq) → template.
/// Each tier is tried in order; the first that is available and succeeds wins.
/// The template tier is guaranteed to be available, so `makeStory` always
/// returns a story and never throws.
struct StoryEngineResolver: Sendable {
    private let tiers: [any StoryEngine]

    init(proxyEndpoint: URL? = AppConfig.proxyEndpoint) {
        var chain: [any StoryEngine] = []
        // The Apple on-device tier only exists on iOS 26+. On older systems the
        // chain simply starts at the proxy, then the always-available template.
        if #available(iOS 26.0, *) {
            chain.append(AppleIntelligenceEngine())
        }
        chain.append(ProxyEngine(endpoint: proxyEndpoint))
        chain.append(TemplateEngine())
        tiers = chain
    }

    /// Init used by tests / previews to inject specific engines.
    init(tiers: [any StoryEngine]) {
        self.tiers = tiers
    }

    func makeStory(for request: StoryRequest) async -> BrokenBoneStory {
        for tier in tiers {
            guard await tier.isAvailable() else { continue }
            do {
                return try await tier.makeStory(for: request)
            } catch {
                // Log-and-continue: drop to the next tier.
                continue
            }
        }
        // Defensive: template should always succeed, but never leave the user empty-handed.
        var rng = SystemRandomNumberGenerator()
        return TemplateEngine.build(from: request, using: &rng)
    }
}
