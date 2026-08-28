import SwiftUI

/// A fixed-width, brandable card designed to be rendered to a PNG and shared
/// to Messages / social. It uses a hard-coded light palette so the exported
/// image looks identical regardless of the device's light/dark setting.
struct ShareCardView: View {
    let story: BrokenBoneStory

    /// The card is laid out at this logical width; height grows to fit the
    /// story. Rendered at 3× for a crisp ~1170pt-wide image.
    static let width: CGFloat = 390

    private let ink = Color(red: 0.13, green: 0.11, blue: 0.10)
    private let inkSoft = Color(red: 0.32, green: 0.29, blue: 0.27)
    private let accent = Color(red: 0.95, green: 0.42, blue: 0.20)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Text(story.title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(story.story)
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundStyle(inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            if let punchline = story.oneLiners.first {
                oneLiner(punchline)
            }

            footer
        }
        .padding(28)
        .frame(width: Self.width, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.97, blue: 0.94),
                    Color(red: 1.0, green: 0.90, blue: 0.83)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("🦴")
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Circle().fill(.white))
                .overlay(Circle().stroke(accent.opacity(0.25), lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text("How'd You Do That?")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                Text("the origin story")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(accent)
            }
            Spacer(minLength: 0)
        }
    }

    private func oneLiner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.opening")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
            Text(text)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .italic()
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 12))
            Text("Made with How'd You Do That?")
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(inkSoft.opacity(0.7))
        .padding(.top, 4)
    }
}

/// A rendered share card ready to hand to `ShareLink`: the PNG on disk plus a
/// SwiftUI `Image` for the share-sheet preview.
struct ShareCard {
    let fileURL: URL
    let preview: Image

    /// Render `story` into a PNG in the temp directory. Must run on the main
    /// actor because `ImageRenderer` walks the SwiftUI view tree.
    @MainActor
    static func render(for story: BrokenBoneStory) -> ShareCard? {
        let renderer = ImageRenderer(content: ShareCardView(story: story))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage,
              let data = uiImage.pngData() else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("howd-you-do-that-\(story.id.uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        return ShareCard(fileURL: url, preview: Image(uiImage: uiImage))
    }
}

#Preview {
    ShareCardView(
        story: BrokenBoneStory(
            title: "Wrist Woes at the Kitchen",
            story: "So I'm in the kitchen, minding my own business, reaching for the top cabinet. I swear, it was just a simple grab, but then — WHAM! My wrist just gave out. Honestly, I was laughing so hard I almost cried.",
            oneLiners: ["I just snapped my wrist trying to get to the top cabinet."],
            source: .appleIntelligence
        )
    )
    .padding()
}
