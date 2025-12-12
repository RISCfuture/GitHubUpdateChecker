import Foundation
import Logging

/// Client for interacting with the GitHub Releases API
public actor GitHubAPIClient {
  private let session: URLSession
  private let baseURL = URL(string: "https://api.github.com")!
  private let decoder: JSONDecoder
  private let logger = Logger(label: "codes.tim.GitHubUpdateChecker.APIClient")

  /// Creates a new GitHub API client
  /// - Parameter session: The URLSession to use for requests
  public init(session: URLSession = .shared) {
    self.session = session
    self.decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
  }

  /// Fetch the latest release for a repository
  /// - Parameters:
  ///   - owner: The repository owner (username or organization)
  ///   - repo: The repository name
  /// - Returns: The latest release
  /// - Throws: UpdateCheckError if the request fails
  public func fetchLatestRelease(owner: String, repo: String) async throws -> GitHubRelease {
    logger.debug(
      "Fetching latest release",
      metadata: [
        "owner": "\(owner)",
        "repo": "\(repo)"
      ]
    )

    let url =
      baseURL
      .appendingPathComponent("repos")
      .appendingPathComponent(owner)
      .appendingPathComponent(repo)
      .appendingPathComponent("releases")
      .appendingPathComponent("latest")

    return try await fetchRelease(from: url)
  }

  /// Fetch all releases for a repository
  /// - Parameters:
  ///   - owner: The repository owner (username or organization)
  ///   - repo: The repository name
  ///   - perPage: Number of releases per page (max 100)
  /// - Returns: Array of releases
  /// - Throws: UpdateCheckError if the request fails
  public func fetchAllReleases(owner: String, repo: String, perPage: Int = 30) async throws
    -> [GitHubRelease]
  {
    logger.debug(
      "Fetching all releases",
      metadata: [
        "owner": "\(owner)",
        "repo": "\(repo)",
        "perPage": "\(perPage)"
      ]
    )

    var url =
      baseURL
      .appendingPathComponent("repos")
      .appendingPathComponent(owner)
      .appendingPathComponent(repo)
      .appendingPathComponent("releases")

    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.queryItems = [URLQueryItem(name: "per_page", value: String(min(perPage, 100)))]

    guard let finalURL = components?.url else {
      throw UpdateCheckError.invalidResponse
    }

    url = finalURL

    let request = makeRequest(for: url)
    let (data, response) = try await performRequest(request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw UpdateCheckError.invalidResponse
    }

    try validateResponse(httpResponse)

    do {
      let releases = try decoder.decode([GitHubRelease].self, from: data)
      logger.info(
        "Fetched releases",
        metadata: [
          "owner": "\(owner)",
          "repo": "\(repo)",
          "count": "\(releases.count)"
        ]
      )
      return releases
    } catch {
      logger.error(
        "Failed to decode releases response",
        metadata: [
          "owner": "\(owner)",
          "repo": "\(repo)",
          "error": "\(error)"
        ]
      )
      throw UpdateCheckError.invalidResponse
    }
  }

  /// Fetch the latest non-prerelease release
  /// - Parameters:
  ///   - owner: The repository owner
  ///   - repo: The repository name
  /// - Returns: The latest stable release, or nil if none found
  public func fetchLatestStableRelease(owner: String, repo: String) async throws -> GitHubRelease? {
    let releases = try await fetchAllReleases(owner: owner, repo: repo)
    return releases.first { !$0.prerelease && !$0.draft }
  }

  /// Fetch a release, optionally including prereleases
  /// - Parameters:
  ///   - owner: The repository owner
  ///   - repo: The repository name
  ///   - includePrereleases: Whether to include prerelease versions
  /// - Returns: The latest applicable release
  public func fetchLatestRelease(owner: String, repo: String, includePrereleases: Bool) async throws
    -> GitHubRelease
  {
    if includePrereleases {
      // Fetch all releases and return the first non-draft
      let releases = try await fetchAllReleases(owner: owner, repo: repo)
      guard let release = releases.first(where: { !$0.draft }) else {
        throw UpdateCheckError.noReleasesFound
      }
      return release
    }
    // Use the /latest endpoint which excludes prereleases
    return try await fetchLatestRelease(owner: owner, repo: repo)
  }

  // MARK: - Private Helpers

  private func fetchRelease(from url: URL) async throws -> GitHubRelease {
    let request = makeRequest(for: url)
    let (data, response) = try await performRequest(request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw UpdateCheckError.invalidResponse
    }

    try validateResponse(httpResponse)

    do {
      let release = try decoder.decode(GitHubRelease.self, from: data)
      logger.info(
        "Fetched release",
        metadata: [
          "tagName": "\(release.tagName)",
          "prerelease": "\(release.prerelease)",
          "assetCount": "\(release.assets.count)"
        ]
      )
      return release
    } catch {
      logger.error(
        "Failed to decode release response",
        metadata: [
          "url": "\(url)",
          "error": "\(error)"
        ]
      )
      throw UpdateCheckError.invalidResponse
    }
  }

  private func makeRequest(for url: URL) -> URLRequest {
    var request = URLRequest(url: url)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("GitHubUpdateChecker/1.0", forHTTPHeaderField: "User-Agent")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    return request
  }

  private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
    do {
      logger.trace(
        "Performing request",
        metadata: [
          "url": "\(request.url?.absoluteString ?? "unknown")"
        ]
      )
      return try await session.data(for: request)
    } catch let error as URLError {
      logger.error(
        "Network request failed",
        metadata: [
          "url": "\(request.url?.absoluteString ?? "unknown")",
          "errorCode": "\(error.code.rawValue)",
          "error": "\(error.localizedDescription)"
        ]
      )
      throw UpdateCheckError.networkError(error.localizedDescription)
    } catch {
      logger.error(
        "Network request failed",
        metadata: [
          "url": "\(request.url?.absoluteString ?? "unknown")",
          "error": "\(error.localizedDescription)"
        ]
      )
      throw UpdateCheckError.networkError(error.localizedDescription)
    }
  }

  private func validateResponse(_ response: HTTPURLResponse) throws {
    switch response.statusCode {
      case 200...299:
        logger.trace(
          "Response validated",
          metadata: [
            "statusCode": "\(response.statusCode)"
          ]
        )
        return
      case 404:
        logger.warning(
          "Repository not found",
          metadata: [
            "statusCode": "\(response.statusCode)"
          ]
        )
        throw UpdateCheckError.repositoryNotFound
      case 403:
        let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining")
        let resetTime = response.value(forHTTPHeaderField: "X-RateLimit-Reset")
        logger.warning(
          "Rate limit or forbidden",
          metadata: [
            "statusCode": "\(response.statusCode)",
            "rateLimitRemaining": "\(remaining ?? "unknown")",
            "rateLimitReset": "\(resetTime ?? "unknown")"
          ]
        )
        if remaining == "0" {
          throw UpdateCheckError.rateLimitExceeded
        }
        throw UpdateCheckError.rateLimitExceeded
      default:
        logger.error(
          "Unexpected response status",
          metadata: [
            "statusCode": "\(response.statusCode)"
          ]
        )
        throw UpdateCheckError.invalidResponse
    }
  }
}
