import XCTest

final class exp_trainerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAllTwentyOneDesignStatesLaunch() throws {
        let states: [(String, String?)] = [
            ("onboarding-1", "screen.onboarding.1"),
            ("onboarding-2", "screen.onboarding.2"),
            ("onboarding-3", "screen.onboarding.3"),
            ("home-empty", "screen.home.empty"),
            ("home-returning", "screen.home.returning"),
            ("new-training", "screen.newTraining"),
            ("training-recording", "screen.training"),
            ("training-paused", "screen.training"),
            ("training-finishing", "screen.training"),
            ("transcript-review", "screen.transcriptReview"),
            ("report-local", "screen.report.local"),
            ("report-ai-loading", "screen.report.aiLoading"),
            ("report-ai-complete", "screen.report.aiComplete"),
            ("history-empty", "screen.history.empty"),
            ("history-list", "screen.history.list"),
            ("settings", "screen.settings"),
            ("overlay-permission", nil),
            ("overlay-speech-preparing", nil),
            ("overlay-interruption", nil),
            ("overlay-abandon", nil),
            ("overlay-delete", nil)
        ]

        for (state, identifier) in states {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-ui-state", state]
            app.launch()
            if let identifier {
                XCTAssertTrue(
                    app.descendants(matching: .any)[identifier].waitForExistence(timeout: 3),
                    "Missing \(identifier) for \(state)"
                )
            } else {
                XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3), "Missing alert for \(state)")
            }
            app.terminate()
        }
    }

    @MainActor
    func testReturningUserCanOpenTrainingConfigurationInTwoActions() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-state", "home-returning"]
        app.launch()
        app.buttons["开始新训练"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.newTraining"].waitForExistence(timeout: 3))
    }
}
