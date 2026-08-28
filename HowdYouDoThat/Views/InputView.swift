import SwiftUI

/// The main flow: collect bone → location/activity → tone → optional flavor
/// across four steps, then push to the result screen.
struct InputView: View {
    @State private var vm = GeneratorViewModel()
    @State private var showResult = false
    @State private var step = 0
    /// True when moving to a later step, false when going back. Drives the
    /// direction of the slide transition.
    @State private var goingForward = true
    @FocusState private var focused: Field?

    private enum Field { case location, activity, audience }

    private let stepCount = 4

    var body: some View {
        VStack(spacing: 0) {
            progressBar

            // The active step. Keying on `step` + a direction-aware transition
            // gives us the card-push animation between screens.
            currentStep
                .id(step)
                .transition(pushTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(swipeGesture)

            navBar
        }
        .navigationTitle("How'd You Do That?")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.selection, trigger: step)
        .sensoryFeedback(.selection, trigger: vm.request.bones)
        .navigationDestination(isPresented: $showResult) {
            ResultView(vm: vm)
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var currentStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch step {
                case 0: boneStep
                case 1: detailsStep
                case 2: toneStep
                default: flavorStep
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var boneStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                emoji: "🦴",
                title: "What did you break?",
                subtitle: "Pick all that apply — I'll hand you back a story worth telling."
            )
            FlowLayout(spacing: 8) {
                ForEach(Bone.allCases) { bone in
                    SelectableChip(
                        title: bone.rawValue,
                        symbol: bone.symbolName,
                        isSelected: vm.request.bones.contains(bone)
                    ) {
                        toggleBone(bone)
                    }
                }
            }

            Divider().padding(.vertical, 4)

            Button(action: surpriseMe) {
                Label("Surprise me", systemImage: "dice.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.accentColor)

            Text("Feeling lazy? We'll roll everything and just make you a story.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                emoji: "📍",
                title: "The boring facts",
                subtitle: "Where it happened and what you were actually doing."
            )
            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("Where were you?")
                TextField("A state, country, the mall…", text: $vm.request.location)
                    .focused($focused, equals: .location)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)

                fieldLabel("What were you actually doing?")
                TextField("Be honest.", text: $vm.request.activity, axis: .vertical)
                    .focused($focused, equals: .activity)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var toneStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                emoji: "🎭",
                title: "Pick a vibe",
                subtitle: "How should this story feel when you tell it?"
            )
            FlowLayout(spacing: 8) {
                ForEach(StoryTone.allCases) { tone in
                    SelectableChip(
                        title: tone.rawValue,
                        emoji: tone.emoji,
                        isSelected: vm.request.tone == tone
                    ) {
                        vm.request.tone = tone
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(vm.request.tone.emoji)
                Text(vm.request.tone.direction.capitalizedFirst)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .id(vm.request.tone)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: vm.request.tone)
        }
    }

    private var flavorStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                emoji: "🌶️",
                title: "Extra flavor",
                subtitle: "All optional. Skip straight to the story if you like."
            )
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Spiciness")
                    Spacer()
                    Text(spiceLabel).foregroundStyle(.secondary).font(.subheadline)
                }
                Slider(value: $vm.request.spiciness, in: 0...1) {
                    Text("Spiciness")
                } minimumValueLabel: {
                    Text("😇").font(.caption)
                } maximumValueLabel: {
                    Text("😈").font(.caption)
                }
            }

            fieldLabel("Who are you trying to impress?")
            TextField("Optional", text: $vm.request.audience)
                .focused($focused, equals: .audience)
                .textFieldStyle(.roundedBorder)

            Toggle("Add an absurd cameo", isOn: $vm.request.embellish)
        }
    }

    // MARK: Pieces

    private func stepHeader(emoji: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emoji).font(.system(size: 44))
            Text(title).font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private var spiceLabel: String {
        switch vm.request.spiceLevel {
        case .clean: return "Clean"
        case .cheeky: return "Cheeky"
        case .wild: return "Wild"
        }
    }

    // MARK: Progress

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepCount, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.accentColor : Color(.systemGray5))
                    .frame(height: 6)
                    .overlay(alignment: .center) {
                        if index == step {
                            Text("🦴")
                                .font(.system(size: 14))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step)
    }

    // MARK: Navigation bar

    private var navBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    advance(to: step - 1)
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .transition(.opacity)
            }

            if step < stepCount - 1 {
                Button {
                    advance(to: step + 1)
                } label: {
                    Text(step == 0 ? "Start" : "Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canAdvanceFromCurrentStep)
            } else {
                Button {
                    makeStory()
                } label: {
                    Text("Make my story")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!vm.request.isReadyToGenerate)
            }
        }
        .padding()
        .background(.bar)
    }

    /// The details step is the only gate: we need a location and an activity
    /// before the story is worth anything.
    private var canAdvanceFromCurrentStep: Bool {
        switch step {
        case 0:
            return !vm.request.bones.isEmpty
        case 1:
            return !vm.request.location.trimmed.isEmpty && !vm.request.activity.trimmed.isEmpty
        default:
            return true
        }
    }

    /// Add or remove a bone from the selection with a light haptic tick.
    private func toggleBone(_ bone: Bone) {
        if vm.request.bones.contains(bone) {
            vm.request.bones.remove(bone)
        } else {
            vm.request.bones.insert(bone)
        }
    }

    /// Kick off generation and navigate to the result screen.
    private func makeStory() {
        focused = nil
        showResult = true
        Task { await vm.generate() }
    }

    /// Roll a completely random request and jump straight to a story.
    private func surpriseMe() {
        vm.request = .random()
        makeStory()
    }

    /// Horizontal swipe to move between steps: left = forward, right = back.
    /// We only act when the drag is clearly horizontal so it doesn't fight the
    /// vertical scroll view, and we honor the same forward-gate as the buttons.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 60, abs(horizontal) > abs(vertical) * 1.5 else { return }

                if horizontal < 0, step < stepCount - 1, canAdvanceFromCurrentStep {
                    advance(to: step + 1)
                } else if horizontal > 0, step > 0 {
                    advance(to: step - 1)
                }
            }
    }

    private func advance(to newStep: Int) {
        focused = nil
        goingForward = newStep > step
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            step = newStep
        }
    }

    /// Slide the outgoing card off one edge while the incoming card slides in
    /// from the other, with a little fade + scale for extra bounce.
    private var pushTransition: AnyTransition {
        let insertionEdge: Edge = goingForward ? .trailing : .leading
        let removalEdge: Edge = goingForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.92)),
            removal: .move(edge: removalEdge)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.92))
        )
    }
}

#Preview {
    NavigationStack { InputView() }
        .modelContainer(for: SavedStory.self, inMemory: true)
}
