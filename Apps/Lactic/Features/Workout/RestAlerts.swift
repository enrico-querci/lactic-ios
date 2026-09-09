import Foundation
import LacticCore
import UIKit
import UserNotifications

/// Tells the client their rest is over, whichever way the phone is being held.
///
/// A rest timer that only draws on screen is useless in the situation it exists
/// for: the phone goes in a pocket or face-down on the bench between sets. So
/// the end of a rest is announced three ways, and each covers a case the others
/// cannot.
///
/// - A **haptic** reaches someone holding the phone with the screen off.
/// - A **local notification** reaches them when the app is backgrounded or the
///   device is locked, which is the common case.
/// - The on-screen countdown covers someone actively watching.
@MainActor
enum RestAlerts {
    private static let identifierPrefix = "rest-timer"

    /// Asked for when a workout **starts**, not when the first set is logged.
    ///
    /// Attaching the prompt to the feature that needs it is right in principle;
    /// attaching it to the first logged set was not. It interrupted the moment
    /// the client was trying to record a set, with nothing on screen explaining
    /// why a workout app wants notifications — and iOS shows the system prompt
    /// exactly once, so a reflexive "Don't Allow" ends rest alerts for good,
    /// recoverable only by digging through Settings.
    ///
    /// At session start nothing is in flight, the client has just committed to
    /// training, and a permission dialog is unremarkable.
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Schedules the end-of-rest alert.
    ///
    /// Keyed per exercise so starting a second timer replaces its own pending
    /// alert rather than stacking another.
    /// Never prompts. If authorization was declined or not yet granted the
    /// alert is simply skipped — the on-screen countdown and the haptic still
    /// work, so a client who said no still gets a usable timer.
    static func schedule(for exerciseKey: String, at deadline: Date, exerciseName: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        else { return }

        let identifier = "\(identifierPrefix)-\(exerciseKey)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let interval = deadline.timeIntervalSinceNow
        // UNTimeIntervalNotificationTrigger rejects anything under a second.
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Rest is over")
        content.body = String(localized: "Next set: \(exerciseName)")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        try? await center.add(request)
    }

    /// Cancels a pending alert when the rest is skipped or the timer ends while
    /// the app is in the foreground — otherwise the notification still fires and
    /// tells them something they have already seen.
    static func cancel(for exerciseKey: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["\(identifierPrefix)-\(exerciseKey)"])
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }
    }

    /// Fired when a rest ends with the app in the foreground.
    static func playFinishedHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Keeps the screen awake for the length of a workout.
    ///
    /// Without this the display sleeps between sets and the client has to
    /// unlock the phone every time they want to log one — with chalky hands,
    /// repeatedly. Scoped to an active session and always restored, so it can
    /// never leak into the rest of the app and drain the battery.
    static func setKeepScreenAwake(_ enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enabled
    }
}
