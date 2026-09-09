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
    private let onFinished: (() -> Void)?

    @State private var deadline: Date?
    @State private var now = Date()

    /// One tick per second is enough for a mm:ss readout, and far cheaper than
    /// a display-linked timer for something that sits on screen for minutes.
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(duration: Int, onFinished: (() -> Void)? = nil) {
        self.duration = duration
        self.onFinished = onFinished
    }

    public var body: some View {
        Group {
            if let deadline {
                running(until: deadline)
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

    public func start() {
        deadline = Date().addingTimeInterval(TimeInterval(duration))
        now = Date()
    }

    private func running(until _: Date) -> some View {
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

    private func finish() {
        deadline = nil
        onFinished?()
    }
}

#Preview("Rest timer") {
    VStack(spacing: LacticSpacing.lg) {
        RestTimerView(duration: 90)
        RestTimerView(duration: 8)
    }
    .padding()
    .background(LacticColor.surface)
}
