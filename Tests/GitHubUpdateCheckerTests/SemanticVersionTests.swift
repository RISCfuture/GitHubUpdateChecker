import Foundation
import Testing

@testable import GitHubUpdateChecker

@Suite
struct `SemanticVersion tests` {
  @Test
  func `Parse standard versions`() {
    let v1 = SemanticVersion("1.0.0")
    #expect(v1?.major == 1)
    #expect(v1?.minor == 0)
    #expect(v1?.patch == 0)

    let v2 = SemanticVersion("2.1.3")
    #expect(v2?.major == 2)
    #expect(v2?.minor == 1)
    #expect(v2?.patch == 3)
  }

  @Test
  func `Parse versions with v prefix`() {
    let v1 = SemanticVersion("v1.0.0")
    #expect(v1?.major == 1)
    #expect(v1?.minor == 0)
    #expect(v1?.patch == 0)

    let v2 = SemanticVersion("V2.0.0")
    #expect(v2?.major == 2)
  }

  @Test
  func `Parse versions with 'version' prefix`() {
    let v = SemanticVersion("version 1.0.0")
    #expect(v?.major == 1)
    #expect(v?.minor == 0)
    #expect(v?.patch == 0)
  }

  @Test
  func `Parse partial versions`() {
    let v1 = SemanticVersion("1.0")
    #expect(v1?.major == 1)
    #expect(v1?.minor == 0)
    #expect(v1?.patch == 0)

    let v2 = SemanticVersion("2")
    #expect(v2?.major == 2)
    #expect(v2?.minor == 0)
    #expect(v2?.patch == 0)
  }

  @Test
  func `Parse prerelease versions`() {
    let v1 = SemanticVersion("1.0.0-beta")
    #expect(v1?.major == 1)
    #expect(v1?.prerelease == "beta")

    let v2 = SemanticVersion("2.0.0-rc.1")
    #expect(v2?.major == 2)
    #expect(v2?.prerelease == "rc.1")
  }

  @Test
  func `Compare versions with Comparable`() {
    let v1 = SemanticVersion("1.0.0")!
    let v2 = SemanticVersion("2.0.0")!
    let v3 = SemanticVersion("1.1.0")!
    let v4 = SemanticVersion("1.0.1")!

    #expect(v1 < v2)
    #expect(v1 < v3)
    #expect(v1 < v4)
    #expect(v2 > v1)
    #expect(v1 == SemanticVersion("1.0.0")!)
  }

  @Test
  func `Compare versions with different formats`() {
    let v1 = SemanticVersion("v1.0.0")!
    let v2 = SemanticVersion("1.0.0")!
    let v3 = SemanticVersion("1.0")!
    let v4 = SemanticVersion("1")!

    #expect(v1 == v2)
    #expect(v2 == v3)
    #expect(v3 == v4)
  }

  @Test
  func `String description`() {
    let v1 = SemanticVersion(major: 1, minor: 2, patch: 3)
    #expect(v1.description == "1.2.3")

    let v2 = SemanticVersion(major: 1, minor: 0, patch: 0, prerelease: "beta")
    #expect(v2.description == "1.0.0-beta")
  }

  @Test
  func `Codable roundtrip`() throws {
    let original = SemanticVersion(major: 1, minor: 2, patch: 3, prerelease: "beta")
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(SemanticVersion.self, from: encoded)
    #expect(decoded == original)
  }

  @Test
  func `Decode from string`() throws {
    let json = "\"1.2.3\""
    let decoded = try JSONDecoder().decode(SemanticVersion.self, from: json.data(using: .utf8)!)
    #expect(decoded.major == 1)
    #expect(decoded.minor == 2)
    #expect(decoded.patch == 3)
  }

  @Test
  func `Invalid version returns nil`() {
    #expect(SemanticVersion("") == nil)
    #expect(SemanticVersion("abc") == nil)
    #expect(SemanticVersion("   ") == nil)
  }
}
