import SwiftUI
import SwiftData

/// Shows the generated story with actions: regenerate, make it wilder,
/// save to the library, and share.
struct ResultView: View {
    @Bindable var vm: GeneratorViewModel
    /// Pops back to a fresh first step. Provided by the presenting InputView.
    var onStartOver: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var didSave = false
    /// The rendered share image for the current story, prepared off the main
    /// interaction so the Share button is instant when tapped.
    @State private var shareCard: ShareCard?
    @State private var showReportConfirm = false
    @State private var showReportFallback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch vm.phase {
                case .generating:
                    generatingView
                case .done:
                    if let story = vm.story {
                        storyCard(story)
                        oneLinersCard(story)
                        if vm.historyCount > 1 { historyPager }
                        actionButtons(story)
                    }
                case .failed(let message):
                    ContentUnavailableView("Something went sideways", systemImage: "exclamationmark.triangle", description: Text(message))
                case .idle:
                    ProgressView()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Your Story")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.smooth, value: vm.phase)
        .onChange(of: vm.story?.id) {
            didSave = false
            shareCard = nil
            if let story = vm.story {
                shareCard = ShareCard.render(for: story)
            }
        }
        .toolbar {
            if vm.story != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showReportConfirm = true
                        } label: {
                            Label("Report this story", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Report this story?",
            isPresented: $showReportConfirm,
            titleVisibility: .visible
        ) {
            Button("Report as inappropriate", role: .destructive) { reportCurrentStory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This opens an email so you can tell us what's wrong. We review every report.")
        }
        .alert("Couldn't open Mail", isPresented: $showReportFallback) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please email \(AppConfig.supportEmail) to report this story.")
        }
    }

    // MARK: Report

    private func reportCurrentStory() {
        guard let story = vm.story else { return }
        let subject = "Reported story: \(story.title)"
        let body = """
        I'm reporting this story as inappropriate.

        —— Story ——
        \(story.title)

        \(story.story)

        \(story.oneLiners.joined(separator: "\n"))
        ——————————

        What's wrong:\u{0020}
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        guard let url = components.url else {
            showReportFallback = true
            return
        }
        openURL(url) { accepted in
            if !accepted { showReportFallback = true }
        }
    }

    // MARK: States

    private var generatingView: some View {
        VStack(spacing: 16) {
            SpinningBone()
            Text("Spinning up your version of events…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    /// Flip between the rolls generated this session.
    private var historyPager: some View {
        HStack {
            Button {
                vm.showPrevious()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
            }
            .disabled(!vm.canGoBack)

            Spacer()

            Text("Roll \(vm.historyPosition) of \(vm.historyCount)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            Spacer()

            Button {
                vm.showNext()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
            }
            .disabled(!vm.canGoForward)
        }
        .tint(.accentColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: Capsule())
        .animation(.snappy, value: vm.historyIndex)
    }

    private func storyCard(_ story: BrokenBoneStory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(story.source.rawValue, systemImage: story.source.badgeSymbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(story.title)
                .font(.title2.bold())
            Text(story.story)
                .font(.body)
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func oneLinersCard(_ story: BrokenBoneStory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Need the short version?")
                .font(.headline)
            ForEach(story.oneLiners, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.caption)
                        .foregroundStyle(.accent)
                    Text(line)
                        .font(.subheadline)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func actionButtons(_ story: BrokenBoneStory) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    Task { await vm.regenerate() }
                } label: {
                    Label("Reroll", systemImage: "dice")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await vm.makeItWilder() }
                } label: {
                    Label("Wilder", systemImage: "flame")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button(action: { save(story) }) {
                    Label(didSave ? "Saved" : "Save", systemImage: didSave ? "checkmark" : "bookmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(didSave)

                if let shareCard {
                    ShareLink(
                        item: shareCard.fileURL,
                        subject: Text(story.title),
                        message: Text(shareText(story)),
                        preview: SharePreview(story.title, image: shareCard.preview)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    // Rendering not ready (or failed): fall back to plain text.
                    ShareLink(item: shareText(story)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button(action: onStartOver) {
                Label("Start a new story", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .tint(.secondary)
            .padding(.top, 4)
        }
        .controlSize(.large)
    }

    // MARK: Actions

    private func save(_ story: BrokenBoneStory) {
        let saved = SavedStory(story: story, request: vm.request)
        modelContext.insert(saved)
        try? modelContext.save()
        didSave = true
    }

    private func shareText(_ story: BrokenBoneStory) -> String {
        var lines = [story.title, "", story.story]
        if let first = story.oneLiners.first {
            lines.append("")
            lines.append("(short version: \(first))")
        }
        return lines.joined(separator: "\n")
    }
}

/// A 🦴 that spins continuously — the loading indicator while a story generates.
private struct SpinningBone: View {
    @State private var spinning = false

    var body: some View {
        Text("🦴")
            .font(.system(size: 52))
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(
                .linear(duration: 1.1).repeatForever(autoreverses: false),
                value: spinning
            )
            .onAppear { spinning = true }
            .accessibilityLabel("Generating your story")
    }
}
