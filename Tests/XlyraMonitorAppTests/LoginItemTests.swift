import Foundation
import XCTest
@testable import XlyraMonitorApp

final class LoginItemTests: XCTestCase {
    func testLegacyConfigurationDefaultsLaunchAtLoginToFalse() throws {
        let (directoryURL, configURL) = try makeTemporaryConfig()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        try Data(#"{"consoleURL":"https://xlyra.example.test"}"#.utf8).write(to: configURL)

        let preferences = XlyraMonitorPreferences(configURL: configURL)

        XCTAssertFalse(preferences.launchAtLogin)
    }

    func testLaunchAtLoginPreferencePersists() throws {
        let (directoryURL, configURL) = try makeTemporaryConfig()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let preferences = XlyraMonitorPreferences(configURL: configURL)
        preferences.launchAtLogin = true

        let reloaded = XlyraMonitorPreferences(configURL: configURL)

        XCTAssertTrue(reloaded.launchAtLogin)
    }

    func testSyncLaunchAtLoginUpdatesConfigurationMirror() throws {
        let (directoryURL, configURL) = try makeTemporaryConfig()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let preferences = XlyraMonitorPreferences(configURL: configURL)
        preferences.syncLaunchAtLogin(true)

        XCTAssertTrue(XlyraMonitorPreferences(configURL: configURL).launchAtLogin)
    }

    private func makeTemporaryConfig() throws -> (URL, URL) {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xlyra-monitor-login-item-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return (directoryURL, directoryURL.appendingPathComponent("config.json"))
    }
}

private enum TestLoginItemError: Error {
    case failed
}

private final class LoginItemManagerSpy: LoginItemManaging {
    var isEnabled: Bool
    var requestedStates: [Bool] = []
    var error: Error?
    var updatesState = true

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        requestedStates.append(isEnabled)
        if let error {
            throw error
        }
        if updatesState {
            self.isEnabled = isEnabled
        }
    }
}

extension LoginItemTests {
    func testApplyEnabledStateRequestsAndVerifiesEnabledState() throws {
        let manager = LoginItemManagerSpy()

        try manager.applyEnabledState(true)

        XCTAssertEqual(manager.requestedStates, [true])
        XCTAssertTrue(manager.isEnabled)
    }

    func testApplyEnabledStatePropagatesManagerFailure() {
        let manager = LoginItemManagerSpy()
        manager.error = TestLoginItemError.failed

        XCTAssertThrowsError(try manager.applyEnabledState(true))
        XCTAssertEqual(manager.requestedStates, [true])
    }

    func testApplyEnabledStateFailsWhenSystemStateDoesNotReachTarget() {
        let manager = LoginItemManagerSpy()
        manager.updatesState = false

        XCTAssertThrowsError(try manager.applyEnabledState(true))
        XCTAssertEqual(manager.requestedStates, [true])
    }

    @MainActor
    func testSettingsViewAcceptsLoginItemManagerProtocol() {
        let preferences = AppPreferences(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let monitorPreferences = XlyraMonitorPreferences(
            configURL: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("xlyra-login-item-view-\(UUID().uuidString).json")
        )
        let monitor = XlyraMonitor(state: XlyraMonitorState(), preferences: monitorPreferences)
        let manager = LoginItemManagerSpy()

        _ = XlyraSettingsWindowView(
            preferences: preferences,
            monitorPreferences: monitorPreferences,
            monitor: monitor,
            loginItem: manager,
            updateCoordinator: XlyraAppUpdateCoordinator()
        )
    }
}
