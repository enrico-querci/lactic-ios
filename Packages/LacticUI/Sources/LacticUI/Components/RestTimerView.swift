import SwiftUI

/// Counts down the rest between sets.
///
/// Driven by a **deadline**, not a decrementing counter. A ticking integer
/// stops when the app is suspended, so a trainee who locks their phone between
/// sets — which is what everyone does — would come back to a timer frozen where
/// they left it. Recomputing from a stored end date is correct across
/// backgrounding, and survives the view being rebuilt.
///
/// Presentational only; the caller owns notifications and haptics.
public struct RestTimerView: View {
    private let duration: Int
    @Binding private var deadline: Date?
    private let onFinished: () -> Void

    @State private var now = Date()

    /// One tick per second is enough for a mm:ss readout, and far cheaper than
    /// a display-linked timer for something that sits on screen for minutes.
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// The deadline is a binding so the workout screen can start the timer
    /// itself when a set is logged. Owning it internally would mean the timer
    /// could only ever be started by tapping it, and reaching for the phone to
    /// press "rest" immediately after a heavy set is exactly the interaction
    /// worth removing.
    public init(duration: Int, deadline: Binding<Date?>, onFinished: @escaping () -> Void = {}) {
        self.duration = duration
        _deadline = deadline
        self.onFinished = onFinished
    }

    public var body: some View {
        RestTimerPanel(
            remaining: remaining, duration: duration, isRunning: deadline != nil,
            start: start, finish: finish
        )
        .onChange(of: deadline) { _, _ in now = Date() }
        .onReceive(tick) { date in
            guard deadline != nil else { return }
            now = date
            if remaining <= 0 {
                finish()
            }
        }
    }

    private var remaining: Int {
        guard let deadline else { return duration }
        return max(0, Int(deadline.timeIntervalSince(now).rounded(.up)))
    }

    private func start() {
        deadline = Date().addingTimeInterval(TimeInterval(duration))
        now = Date()
    }

    private func finish() {
        deadline = nil
        onFinished()
    }
}

private struct RestTimerPanel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let remaining: Int
    let duration: Int
    let isRunning: Bool
    let start: () -> Void
    let finish: () -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: LacticSpacing.sm))
            : AnyLayout(HStackLayout(spacing: LacticSpacing.md))

        VStack(alignment: .leading, spacing: LacticSpacing.md) {
            layout {
                VStack(alignment: .leading, spacing: LacticSpacing.xs) {
                    // Lactic's shared component translations live in the app catalog.
                    Label { Text("Rest", bundle: .main) } icon: { Image(systemName: "timer") }
                        .font(.lacticEyebrow)
                        .foregroundStyle(isRunning ? LacticColor.textOnHero : LacticColor.textSecondary)
                    Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
                        .font(.lacticTimer)
                        .foregroundStyle(isRunning ? LacticColor.brand : LacticColor.textPrimary)
                        .contentTransition(.numericText())
                        .accessibilityLabel(Text("\(remaining) seconds of rest remaining", bundle: .main))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: isRunning ? finish : start) {
                    if isRunning {
                        Text("Skip", bundle: .main)
                    } else {
                        Text("Rest \(duration)s", bundle: .main)
                    }
                }
                .lacticButton(.secondary, size: .small)
            }
            ProgressView(value: Double(min(remaining, duration)), total: Double(max(duration, 1)))
                .tint(isRunning ? LacticColor.brand : LacticColor.borderStrong)
                .accessibilityHidden(true)
        }
        .padding(LacticSpacing.lg)
        .background(
            isRunning ? LacticColor.heroSurface : LacticColor.surfacePressed,
            in: RoundedRectangle(cornerRadius: LacticRadius.control)
        )
    }
}

#Preview("Rest timer") {
    @Previewable @State var idle: Date?
    @Previewable @State var running: Date? = Date().addingTimeInterval(85)

    return VStack(spacing: LacticSpacing.lg) {
        RestTimerView(duration: 90, deadline: $idle)
        RestTimerView(duration: 90, deadline: $running)
    }
    .padding()
    .background(LacticColor.surface)
}
