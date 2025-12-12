import Foundation
import Testing

@testable import GitHubUpdateChecker

@Suite("GitHubAsset")
struct GitHubAssetTests {
  @Test("Formatted size")
  func formattedSize() {
    let smallAsset = GitHubAsset(
      id: 1,
      name: "small.zip",
      browserDownloadURL: URL(string: "https://example.com/small.zip")!,
      size: 1024,
      contentType: "application/zip",
      downloadCount: 0
    )
    #expect(smallAsset.formattedSize.contains("KB") || smallAsset.formattedSize.contains("bytes"))

    let largeAsset = GitHubAsset(
      id: 2,
      name: "large.dmg",
      browserDownloadURL: URL(string: "https://example.com/large.dmg")!,
      size: 52_428_800,  // 50 MB
      contentType: "application/octet-stream",
      downloadCount: 0
    )
    #expect(largeAsset.formattedSize.contains("MB"))
  }
}
