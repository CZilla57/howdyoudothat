import Foundation

/// Build-time configuration read from the app's Info.plist.
///
/// The proxy endpoint lives in the `StoryProxyEndpoint` Info.plist key
/// (injected via the `INFOPLIST_KEY_StoryProxyEndpoint` build setting). It is
/// empty until the Cloudflare Worker is deployed and the URL is filled in, at
/// which point the proxy tier switches itself on with no code change.
enum AppConfig {
    /// The deployed proxy Worker URL, or `nil` when unconfigured / invalid.
    static var proxyEndpoint: URL? {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "StoryProxyEndpoint") as? String
        else { return nil }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let url = URL(string: trimmed),
            url.scheme == "https"
        else { return nil }

        return url
    }

    /// Where "Report this story" emails are sent. Update this to a real inbox
    /// you monitor before shipping — App Review expects a working report path.
    static let supportEmail = "support@howdyoudothat.app"
}
