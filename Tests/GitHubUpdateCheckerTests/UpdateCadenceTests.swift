import Foundation
import Testing

@testable import GitHubUpdateChecker

@Suite("UpdateCadence")
struct UpdateCadenceTests {
  @Test("Time intervals are correct")
  func timeIntervals() {
    #expect(UpdateCadence.hourly.timeInterval == 3600)
    #expect(UpdateCadence.daily.timeInterval == 86400)
    #expect(UpdateCadence.weekly.timeInterval == 604800)
    #expect(UpdateCadence.never.timeInterval == nil)
  }

  @Test("Display names are set")
  func displayNames() {
    #expect(UpdateCadence.hourly.displayName == "Hourly")
    #expect(UpdateCadence.daily.displayName == "Daily")
    #expect(UpdateCadence.weekly.displayName == "Weekly")
    #expect(UpdateCadence.never.displayName == "Never")
  }

  @Test("Codable roundtrip")
  func codableRoundtrip() throws {
    for cadence in UpdateCadence.allCases {
      let encoded = try JSONEncoder().encode(cadence)
      let decoded = try JSONDecoder().decode(UpdateCadence.self, from: encoded)
      #expect(decoded == cadence)
    }
  }
}
