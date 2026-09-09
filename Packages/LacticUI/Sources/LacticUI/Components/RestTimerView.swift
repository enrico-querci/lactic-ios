import SwiftUI

/// Counts down the rest between sets.
///
/// Driven by a **deadline**, not a decrementing counter. A ticking integer
/// stops when the app is suspended, so a trainee who locks their phone between
/// sets — which is what everyone does — would come back to a timer frozen where
/// they left it. Recomputing from a stored end date is correct across
/// backgrounding, and survives the view being rebuilt.
///
/// Presentational only. Haptics, a local notification for when the app is
/// backgrounded, and holding the screen awake belong with the rest of the
/// workout polish and are not here yet.
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
        Group {
            if deadline != nil {
                running
            } else {
                Button("Rest \(duration)s") { start() }
                    .lacticButton(.secondary, size: .small)
                    .fixedSize()
            }
        }
        .onReceive(tick) { date in
            guard deadline != nil else { return }
            now = date
            if remaining <= 0 {
                finish()
            }
        }
    }

    private var running: some View {
        HStack(spacing: LacticSpacing.sm) {
            Text(formatted)
                .font(.lacticTimer)
                .foregroundStyle(remaining <= 10 ? LacticColor.danger : LacticColor.textPrimary)
                .contentTransition(.numericText())
                .accessibilityLabel("\(remaining) seconds of rest remaining")

            Button("Skip") { finish() }
                .lacticButton(.secondary, size: .small)
                .fixedSize()
        }
    }

    private var remaining: Int {
        guard let deadline else { return duration }
        return max(0, Int(deadline.timeIntervalSince(now).rounded(.up)))
    }

    private var formatted: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
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
