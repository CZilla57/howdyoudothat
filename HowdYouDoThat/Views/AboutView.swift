import SwiftUI

/// Submission-facing privacy and support information that remains reachable
/// from the main creation screen without requiring an account or a story.
struct AboutView: View {
    @AppStorage("allowCloudFallback") private var allowCloudFallback = true

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Text("🦴")
                        .font(.system(size: 54))
                    Text("How'd You Do That?")
                        .font(.title2.bold())
                    Text("Turn the boring truth into a story worth telling.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section("Story privacy") {
                Toggle("Allow cloud AI fallback", isOn: $allowCloudFallback)

                Text(cloudExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Link(destination: AppConfig.privacyPolicyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            }

            Section("Support") {
                Link(destination: AppConfig.supportURL) {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }

                Link(destination: supportEmailURL) {
                    Label(AppConfig.supportEmail, systemImage: "envelope")
                }
            }

            Section("About") {
                LabeledContent("Version", value: versionDescription)
                Text("For entertainment only. This app does not provide medical advice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cloudExplanation: String {
        if allowCloudFallback {
            return "When Apple Intelligence is unavailable or slow, your story details may be sent through our Cloudflare service to Groq or Google Gemini."
        }
        return "Story details stay on this device. The classic offline generator is used when Apple Intelligence is unavailable."
    }

    private var supportEmailURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "How'd You Do That? Support")
        ]
        return components.url ?? AppConfig.supportURL
    }

    private var versionDescription: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "—"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack { AboutView() }
}
