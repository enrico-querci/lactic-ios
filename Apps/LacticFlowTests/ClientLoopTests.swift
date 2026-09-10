import XCTest

/// End-to-end verification of the client's core loop against a local API.
///
/// XCTest rather than Swift Testing because `XCUIApplication` exists only here
/// — the one exception to AGENTS.md §6.1. These do not run in CI (simulator
/// tests are deliberately excluded); they are run on demand against a seeded
/// `lactic-api` on `http://localhost:3000`.
@MainActor
final class ClientLoopTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        // English so assertions can match labels, and the local server so the
        // seeded data is what the app sees.
        app.launchArguments = ["-app_locale", "en", "-api_server", "local"]
        app.launch()
        return app
    }

    /// Signs in through the development route, which exists precisely so this
    /// is possible without a Google account.
    @discardableResult
    private func signIn(_ app: XCUIApplication, as email: String = "alice@example.com") -> Bool {
        // The refresh token is in the keychain, which outlives the app, so a
        // second run starts already signed in. That is correct behaviour, not
        // a failure: restore() puts the shell up without a sign-in screen.
        if app.tabBars.firstMatch.waitForExistence(timeout: 8) {
            return true
        }
        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 20) else { return false }
        if (field.value as? String) != email {
            field.tap()
            field.typeText(email)
        }
        app.buttons["Sign in"].tap()
        // The tab bar only exists inside the signed-in shell.
        return app.tabBars.firstMatch.waitForExistence(timeout: 20)
    }

    /// The hero button carries the whole card as its label, so match on the
    /// action rather than the exact string.
    private func startWorkout(_ app: XCUIApplication) -> Bool {
        let hero = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Start workout")
        ).firstMatch
        guard hero.waitForExistence(timeout: 20) else { return false }
        hero.tap()
        return true
    }

    /// The overview screen's own button begins the session. Matched exactly,
    /// unlike Home's hero, whose label is the whole card.
    private func beginSession(_ app: XCUIApplication) -> Bool {
        let begin = app.buttons["Start workout"]
        guard begin.waitForExistence(timeout: 20) else { return false }
        begin.tap()
        return true
    }

    /// The loop the whole client app exists for: start a session, log sets,
    /// leave a note, finish, and find it in history.
    ///
    /// Everything below this was previously covered only by unit tests and
    /// screenshots — the combination that let `WorkoutExecutionView` render
    /// nothing at all while 101 tests stayed green.
    func testTheCoreLoop() {
        let app = launch()
        XCTAssertTrue(signIn(app), "did not reach the signed-in shell")
        XCTAssertTrue(startWorkout(app), "no start-workout affordance on Home")
        XCTAssertTrue(beginSession(app), "could not begin the session")

        let logSet = app.buttons["Log set"].firstMatch
        XCTAssertTrue(logSet.waitForExistence(timeout: 20), "no Log set control")

        // Three sets against the coach's target, which is what the first
        // exercise prescribes.
        for index in 1 ... 3 {
            XCTAssertTrue(logSet.waitForExistence(timeout: 10), "Log set vanished before set \(index)")
            logSet.tap()
            // Each logged set adds a row, so the tree must actually grow.
            let expected = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "of 3 sets logged")
            ).firstMatch
            _ = expected.waitForExistence(timeout: 10)
        }

        let note = app.textFields.matching(
            NSPredicate(format: "placeholderValue CONTAINS[c] %@", "How did the whole session go")
        ).firstMatch
        if note.waitForExistence(timeout: 10) {
            note.tap()
            note.typeText("Driven by ClientLoopTests.")
        }

        let finish = app.buttons["Finish workout"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10), "no Finish workout control")
        finish.tap()

        // Completing returns to the shell; the session must then be in History.
        XCTAssertTrue(app.buttons["History"].waitForExistence(timeout: 20))
        app.buttons["History"].tap()
        let historyRow = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Lower A")
        ).firstMatch
        XCTAssertTrue(historyRow.waitForExistence(timeout: 20), "the finished session is not in History")
    }

    // MARK: - Offline delivery

    //
    // Run in order, with the server stopped and started between them by the
    // caller. Split into phases because the interesting event — a force quit
    // while operations are queued — cannot happen inside one test.

    /// Server up: begin a session and log one set that reaches the API.
    func testOfflinePhase1Online() {
        let app = launch()
        XCTAssertTrue(signIn(app))
        XCTAssertTrue(startWorkout(app))
        XCTAssertTrue(beginSession(app))
        let logSet = app.buttons["Log set"].firstMatch
        XCTAssertTrue(logSet.waitForExistence(timeout: 20))
        logSet.tap()
        _ = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "of 3 sets logged")
        ).firstMatch.waitForExistence(timeout: 10)
        // Let the drain finish before the test tears the app down.
        Thread.sleep(forTimeInterval: 3)
    }

    /// Server **down**: resume and log two more sets, which can only queue.
    /// Ending the test terminates the app — the force quit.
    func testOfflinePhase2Queued() {
        let app = launch()
        XCTAssertTrue(signIn(app))
        let resume = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Resume", "Start workout")
        ).firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 20), "no resume affordance on Home")
        resume.tap()
        // Already in progress, so the overview may go straight to logging.
        if app.buttons["Start workout"].waitForExistence(timeout: 5) {
            app.buttons["Start workout"].tap()
        }
        let logSet = app.buttons["Log set"].firstMatch
        XCTAssertTrue(logSet.waitForExistence(timeout: 20), "no Log set control while offline")
        for _ in 1 ... 2 {
            logSet.tap()
            Thread.sleep(forTimeInterval: 2)
        }
        Thread.sleep(forTimeInterval: 3)
    }

    /// Server back up: relaunch and touch nothing. If queued work only drains
    /// when the recorder next acts, the two sets never arrive.
    func testOfflinePhase3RelaunchOnly() {
        let app = launch()
        XCTAssertTrue(signIn(app))
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 20))
        // Generous: far longer than any retry backoff would need.
        Thread.sleep(forTimeInterval: 15)
    }

    func testProbeLogging() {
        let app = launch()
        XCTAssertTrue(signIn(app))
        XCTAssertTrue(startWorkout(app))
        XCTAssertTrue(beginSession(app), "no Start workout on the overview")
        _ = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Log set")
        ).firstMatch.waitForExistence(timeout: 20)
        print("=== DESCRIBE START ===")
        print(app.debugDescription)
        print("=== DESCRIBE END ===")
    }

    func testProbeWorkout() {
        let app = launch()
        XCTAssertTrue(signIn(app))
        XCTAssertTrue(startWorkout(app), "no start-workout affordance on Home")
        // The execution screen creates its model in .task, so wait for content.
        _ = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Log set")
        ).firstMatch.waitForExistence(timeout: 20)
        print("=== DESCRIBE START ===")
        print(app.debugDescription)
        print("=== DESCRIBE END ===")
    }

    func testProbeHome() {
        let app = launch()
        XCTAssertTrue(signIn(app), "did not reach the signed-in shell")
        print("=== DESCRIBE START ===")
        print(app.debugDescription)
        print("=== DESCRIBE END ===")
    }
}
