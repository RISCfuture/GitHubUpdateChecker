import Foundation
import Testing

@testable import GitHubUpdateChecker

@Suite("GitHubRelease")
struct GitHubReleaseTests {
  @Test("Version extraction from tag")
  func versionExtraction() {
    let release = makeRelease(tagName: "v1.2.3")
    #expect(release.version == SemanticVersion(major: 1, minor: 2, patch: 3))

    let release2 = makeRelease(tagName: "1.2.3")
    #expect(release2.version == SemanticVersion(major: 1, minor: 2, patch: 3))
  }

  @Test("Primary asset selection prefers DMG")
  func primaryAssetSelectionDMG() {
    let release = makeRelease(assets: [
      makeAsset(name: "app.zip"),
      makeAsset(name: "app.dmg"),
      makeAsset(name: "app.pkg")
    ])
    #expect(release.primaryAsset?.name == "app.dmg")
  }

  @Test("Primary asset selection falls back to ZIP")
  func primaryAssetSelectionZIP() {
    let release = makeRelease(assets: [
      makeAsset(name: "app.tar.gz"),
      makeAsset(name: "app.zip")
    ])
    #expect(release.primaryAsset?.name == "app.zip")
  }

  @Test("Asset matching with pattern")
  func assetMatchingWithPattern() {
    let release = makeRelease(assets: [
      makeAsset(name: "app-x86.dmg"),
      makeAsset(name: "app-arm64.dmg")
    ])
    let match = release.asset(matching: "arm64")
    #expect(match?.name == "app-arm64.dmg")
  }

  @Test("JSON decoding from GitHub API format")
  func jsonDecoding() throws {
    let json = """
      {
          "id": 12345,
          "tag_name": "v2.0.0",
          "name": "Version 2.0.0",
          "body": "Release notes here",
          "html_url": "https://github.com/owner/repo/releases/tag/v2.0.0",
          "published_at": "2024-01-15T10:30:00Z",
          "prerelease": false,
          "draft": false,
          "assets": [
              {
                  "id": 1,
                  "name": "app.dmg",
                  "browser_download_url": \
      "https://github.com/owner/repo/releases/download/v2.0.0/app.dmg",
                  "size": 52428800,
                  "content_type": "application/octet-stream",
                  "download_count": 100
              }
          ]
      }
      """

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let release = try decoder.decode(GitHubRelease.self, from: json.data(using: .utf8)!)

    #expect(release.id == 12345)
    #expect(release.tagName == "v2.0.0")
    #expect(release.version == SemanticVersion(major: 2, minor: 0, patch: 0))
    #expect(release.name == "Version 2.0.0")
    #expect(release.body == "Release notes here")
    #expect(release.prerelease == false)
    #expect(release.draft == false)
    #expect(release.assets.count == 1)
    #expect(release.assets[0].name == "app.dmg")
    #expect(release.assets[0].size == 52_428_800)
  }

  // MARK: - Test Helpers

  private func makeRelease(
    tagName: String = "v1.0.0",
    assets: [GitHubAsset] = []
  ) -> GitHubRelease {
    GitHubRelease(
      id: 1,
      tagName: tagName,
      name: "Test Release",
      body: "Test body",
      htmlURL: URL(string: "https://github.com/test/repo")!,
      publishedAt: Date(),
      assets: assets,
      prerelease: false,
      draft: false
    )
  }

  private func makeAsset(name: String) -> GitHubAsset {
    GitHubAsset(
      id: 1,
      name: name,
      browserDownloadURL: URL(
        string: "https://github.com/test/repo/releases/download/v1.0.0/\(name)"
      )!,
      size: 1024,
      contentType: "application/octet-stream",
      downloadCount: 0
    )
  }
}
