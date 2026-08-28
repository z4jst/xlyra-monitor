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
