import SwiftUI

/// Plays an exercise demonstration.
///
/// Takes a `load` closure rather than an API client, so `LacticUI` stays
/// independent of `LacticKit` and the view is trivially previewable.
///
/// **Never prefetch this.** The bytes come through an authenticated proxy that
/// draws on a metered provider quota, so one fetch per exercise the user
/// actually asked to see — the same reason the web keeps it behind an explicit
/// toggle rather than rendering it inline in a list.
public struct AnimatedExerciseImage: View {
    private enum Phase {
        case loading
        case playing(GIFAnimation)
        case failed
    }

    private let cacheKey: String
    private let load: @Sendable () async throws -> Data
    private let cache: AnimationCache

    @State private var phase: Phase = .loading
    @State private var frameIndex = 0
    @State private var attempt = 0

    public init(
        cacheKey: String,
        cache: AnimationCache = .shared,
        load: @escaping @Sendable () async throws -> Data
    ) {
        self.cacheKey = cacheKey
        self.cache = cache
        self.load = load
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 192)
            .background(LacticColor.surfacePressed)
            .clipShape(RoundedRectangle(cornerRadius: LacticRadius.card, style: .continuous))
            .task(id: attempt) { await start() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
                .controlSize(.regular)
                .accessibilityLabel("Loading demonstration")

        case .playing(let animation):
            // `decorative:` because the image conveys nothing a screen-reader
            // user can act on; the exercise name beside it already names it.
            Image(decorative: animation.frames[min(frameIndex, animation.frames.count - 1)].image, scale: 1)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)

        case .failed:
            VStack(spacing: LacticSpacing.sm) {
                Text("Demonstration unavailable")
                    .font(.lacticCaption)
                    .foregroundStyle(LacticColor.textSecondary)
                Button("Try again") { attempt += 1 }
                    .lacticButton(.secondary, size: .small)
                    .fixedSize()
            }
        }
    }

    private func start() async {
        phase = .loading
        frameIndex = 0

        guard let data = await bytes() else {
            phase = .failed
            return
        }
        guard let animation = GIFAnimation(data: data) else {
            phase = .failed
            return
        }

        phase = .playing(animation)
        await play(animation)
    }

    private func bytes() async -> Data? {
        if let cached = await cache.data(for: cacheKey) {
            return cached
        }
        guard let fetched = try? await load() else { return nil }
        await cache.store(fetched, for: cacheKey)
        return fetched
    }

    /// Advances frames on their own declared timing.
    ///
    /// Driven by sleeps rather than a display link because GIF frames have
    /// individual, irregular durations that a fixed tick cannot honour. The
    /// loop ends when the task is cancelled, which SwiftUI does on disappear —
    /// so a scrolled-away animation stops costing anything.
    private func play(_ animation: GIFAnimation) async {
        guard animation.isAnimated else { return }
        while !Task.isCancelled {
            let duration = animation.frames[frameIndex].duration
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            frameIndex = (frameIndex + 1) % animation.frames.count
        }
    }
}

/// The toggle that gates the animation, matching the web's behaviour: nothing
/// is requested until the user asks, and the control is absent entirely for an
/// exercise the catalogue has no animation for.
public struct ExerciseDemonstration: View {
    private let cacheKey: String
    private let hasAnimation: Bool
    private let load: @Sendable () async throws -> Data

    @State private var isShown = false

    public init(
        cacheKey: String,
        hasAnimation: Bool,
        load: @escaping @Sendable () async throws -> Data
    ) {
        self.cacheKey = cacheKey
        self.hasAnimation = hasAnimation
        self.load = load
    }

    public var body: some View {
        if hasAnimation {
            VStack(alignment: .leading, spacing: LacticSpacing.sm) {
                Button(isShown ? "Hide demonstration" : "Show demonstration") {
                    withAnimation(.easeInOut(duration: 0.2)) { isShown.toggle() }
                }
                .lacticButton(.secondary, size: .small)
                .fixedSize()

                if isShown {
                    AnimatedExerciseImage(cacheKey: cacheKey, load: load)
                }
            }
        }
    }
}
