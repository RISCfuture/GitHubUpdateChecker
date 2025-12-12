import Foundation
import Testing

@testable import GitHubUpdateChecker

@Suite("UpdatePreferences")
@MainActor
struct UpdatePreferencesTests {
  @Test("Skip version management")
  func skipVersionManagement() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let prefs = UpdatePreferences(defaults: defaults)
    let version = SemanticVersion(major: 1, minor: 0, patch: 0)

    #expect(prefs.isVersionSkipped(version) == false)

    prefs.skipVersion(version)
    #expect(prefs.isVersionSkipped(version) == true)

    prefs.resetSkippedVersions()
    #expect(prefs.isVersionSkipped(version) == false)
  }

  @Test("Cadence persistence")
  func cadencePersistence() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let prefs = UpdatePreferences(defaults: defaults)

    prefs.updateCadence = .weekly
    #expect(prefs.updateCadence == .weekly)

    // Create new instance to verify persistence
    let prefs2 = UpdatePreferences(defaults: defaults)
    #expect(prefs2.updateCadence == .weekly)
  }

  @Test("Default values")
  func defaultValues() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let prefs = UpdatePreferences(defaults: defaults)

    #expect(prefs.updateCadence == .daily)
    #expect(prefs.automaticDownload == false)
    #expect(prefs.lastCheckTimestamp == nil)
    #expect(prefs.skippedVersions.isEmpty)
    #expect(prefs.checkForPrereleases == false)
  }

  @Test("Reset to defaults")
  func resetToDefaults() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let prefs = UpdatePreferences(defaults: defaults)

    prefs.updateCadence = .weekly
    prefs.automaticDownload = true
    prefs.skipVersion(SemanticVersion(major: 1, minor: 0, patch: 0))

    prefs.resetToDefaults()

    #expect(prefs.updateCadence == .daily)
    #expect(prefs.automaticDownload == false)
    #expect(prefs.skippedVersions.isEmpty)
  }
}
