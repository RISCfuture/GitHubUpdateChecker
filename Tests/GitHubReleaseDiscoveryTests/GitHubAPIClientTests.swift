import Foundation
import Testing

@testable import GitHubReleaseDiscovery

@Suite
struct `GitHub API response classification` {
  private static func response(status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
    HTTPURLResponse(
      url: URL(string: "https://api.github.com/repos/owner/repo/releases")!,
      statusCode: status,
      httpVersion: nil,
      headerFields: headers
    )!
  }

  @Test(arguments: [
    (403, ["X-RateLimit-Remaining": "0"]),
    (429, ["X-RateLimit-Remaining": "0"]),
    (403, ["X-RateLimit-Remaining": "12", "Retry-After": "60"]),
    (429, ["Retry-After": "60"])
  ])
  func `treats a rate-limited rejection as rate limiting`(status: Int, headers: [String: String]) {
    let error = GitHubAPIClient.error(for: Self.response(status: status, headers: headers))
    #expect({ if case .rateLimitExceeded = error { true } else { false } }())
  }

  @Test
  func `treats a forbidden response with quota remaining as invalid`() {
    let response = Self.response(status: 403, headers: ["X-RateLimit-Remaining": "42"])
    let error = GitHubAPIClient.error(for: response)
    #expect({ if case .invalidResponse = error { true } else { false } }())
  }

  @Test
  func `passes successes and distinguishes a missing repository`() {
    #expect(GitHubAPIClient.error(for: Self.response(status: 200)) == nil)
    let error = GitHubAPIClient.error(for: Self.response(status: 404))
    #expect({ if case .repositoryNotFound = error { true } else { false } }())
  }
}
