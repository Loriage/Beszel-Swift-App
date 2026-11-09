import XCTest

@MainActor
final class AuthenticationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(serverError: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--ui-testing-authentication", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if serverError { app.launchArguments.append("--ui-testing-auth-server-error") }
        app.launch()
        return app
    }

    private func openLogin(_ app: XCUIApplication) {
        let action = app.buttons["monitoring.retry"]
        XCTAssertTrue(action.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(["Sign in again", "Se reconnecter"].contains(action.label), action.label)
        action.tap()
        XCTAssertTrue(app.buttons["onboarding.provider.oidc"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(app.textFields["onboarding.email"].value as? String, "test@example.invalid")
    }

    func testExpiredSessionOpensLoginAndCanBeCancelled() {
        let app = launch()
        openLogin(app)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Direct OIDC sign-in"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["reauthentication.cancel"].tap()
        XCTAssertTrue(app.buttons["monitoring.retry"].waitForExistence(timeout: 5))
        openLogin(app)
    }

    func testPasswordSignInReloadsTheSameInstance() {
        let app = launch()
        openLogin(app)
        app.secureTextFields["onboarding.password"].tap()
        app.secureTextFields["onboarding.password"].typeText("fixture-password")
        app.buttons["onboarding.passwordSignIn"].tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(app.buttons["reauthentication.cancel"].exists)
    }

    func testOIDCSignInAndExpirationWhileOpen() async throws {
        let app = launch()
        openLogin(app)
        app.buttons["onboarding.provider.oidc"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let consent = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Continue", "Continuer"])).firstMatch
        if consent.waitForExistence(timeout: 5) { consent.tap() }
        let appConsent = app.buttons.matching(NSPredicate(format: "label IN %@", ["Continue", "Continuer"])).firstMatch
        if appConsent.exists { appConsent.tap() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        var expire = URLRequest(url: URL(string: "http://127.0.0.1:47898/test/expire")!)
        expire.httpMethod = "POST"
        _ = try await URLSession.shared.data(for: expire)
        XCTAssertTrue(app.buttons["monitoring.retry"].waitForExistence(timeout: 25), app.debugDescription)
        openLogin(app)
    }

    func testServerFailureKeepsRetry() {
        let app = launch(serverError: true)
        let action = app.buttons["monitoring.retry"]
        XCTAssertTrue(action.waitForExistence(timeout: 15))
        XCTAssertTrue(["Retry", "Réessayer"].contains(action.label), action.label)
        action.tap()
        XCTAssertTrue(action.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["onboarding.provider.oidc"].exists)
    }
}
