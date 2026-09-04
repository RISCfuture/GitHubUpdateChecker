import Foundation
import Testing

@testable import GitHubUpdateChecker

@Suite
struct `UpdateCadence tests` {
  @Test
  func `Time intervals are correct`() {
    #expect(UpdateCadence.hourly.timeInterval == 3600)
    #expect(UpdateCadence.daily.timeInterval == 86400)
    #expect(UpdateCadence.weekly.timeInterval == 604800)
    #expect(UpdateCadence.never.timeInterval == nil)
  }

  @Test
  func `Display names are set`() {
    #expect(UpdateCadence.hourly.displayName == "Hourly")
    #expect(UpdateCadence.daily.displayName == "Daily")
    #expect(UpdateCadence.weekly.displayName == "Weekly")
    #expect(UpdateCadence.never.displayName == "Never")
  }

  @Test
  func `Codable roundtrip`() throws {
    for cadence in UpdateCadence.allCases {
      let encoded = try JSONEncoder().encode(cadence)
      let decoded = try JSONDecoder().decode(UpdateCadence.self, from: encoded)
      #expect(decoded == cadence)
    }
  }
}
