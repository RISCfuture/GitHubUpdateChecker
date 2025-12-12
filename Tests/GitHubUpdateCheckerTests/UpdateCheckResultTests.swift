import Foundation
import Testing

@testable import GitHubUpdateChecker

@Suite("UpdateCheckResult")
struct UpdateCheckResultTests {
  @Test("hasUpdate returns true only for updateAvailable")
  func hasUpdate() {
    let release = makeRelease()

    #expect(UpdateCheckResult.updateAvailable(release).hasUpdate == true)
    #expect(UpdateCheckResult.noUpdateAvailable.hasUpdate == false)
    #expect(UpdateCheckResult.skippedVersion(release).hasUpdate == false)
    #expect(UpdateCheckResult.error(.networkError("test")).hasUpdate == false)
  }

  @Test("release property extracts release when available")
  func releaseProperty() {
    let release = makeRelease()

    #expect(UpdateCheckResult.updateAvailable(release).release != nil)
    #expect(UpdateCheckResult.skippedVersion(release).release != nil)
    #expect(UpdateCheckResult.noUpdateAvailable.release == nil)
    #expect(UpdateCheckResult.error(.networkError("test")).release == nil)
  }

  // MARK: - Test Helpers

  private func makeRelease() -> GitHubRelease {
    GitHubRelease(
      id: 1,
      tagName: "v1.0.0",
      name: "Test",
      body: nil,
      htmlURL: URL(string: "https://github.com/test/repo")!,
      publishedAt: nil,
      assets: [],
      prerelease: false,
      draft: false
    )
  }
}
