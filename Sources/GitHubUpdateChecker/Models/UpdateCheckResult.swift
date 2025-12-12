import Foundation

/// The result of checking for updates.
///
/// This enum represents all possible outcomes when calling
/// ``GitHubUpdateChecker/GitHubUpdateChecker/checkForUpdates()``.
///
/// ## Handling Results
///
/// ```swift
/// let result = try await checker.checkForUpdates()
///
/// switch result {
/// case .updateAvailable(let release):
///     print("Version \(release.version) available!")
///
/// case .noUpdateAvailable:
///     print("You're up to date.")
///
/// case .skippedVersion(let release):
///     print("Version \(release.version) was skipped.")
///
/// case .error(let error):
///     print("Error: \(error.localizedDescription)")
/// }
/// ```
///
/// ## Topics
///
/// ### Cases
///
/// - ``updateAvailable(_:)``
/// - ``noUpdateAvailable``
/// - ``skippedVersion(_:)``
/// - ``error(_:)``
///
/// ### Convenience Properties
///
/// - ``hasUpdate``
/// - ``release``
public enum UpdateCheckResult: Sendable {
  /// A new version is available for download.
  ///
  /// The associated ``GitHubRelease`` contains version information,
  /// release notes, and downloadable assets.
  case updateAvailable(GitHubRelease)

  /// The current version is up to date.
  ///
  /// No newer release was found on GitHub.
  case noUpdateAvailable

  /// An update exists but the user has chosen to skip this version.
  ///
  /// The user previously clicked "Skip This Version" for this release.
  /// The associated ``GitHubRelease`` is provided for reference.
  case skippedVersion(GitHubRelease)

  /// An error occurred while checking for updates.
  ///
  /// See ``UpdateCheckError`` for possible error types.
  case error(UpdateCheckError)

  /// Whether an actionable update is available.
  ///
  /// Returns `true` only for ``updateAvailable(_:)``.
  /// Skipped versions return `false` since they shouldn't prompt the user.
  public var hasUpdate: Bool {
    if case .updateAvailable = self {
      return true
    }
    return false
  }

  /// The release associated with this result, if any.
  ///
  /// Returns the ``GitHubRelease`` for both ``updateAvailable(_:)``
  /// and ``skippedVersion(_:)`` cases. Returns `nil` for
  /// ``noUpdateAvailable`` and ``error(_:)``.
  public var release: GitHubRelease? {
    switch self {
      case .updateAvailable(let release), .skippedVersion(let release):
        return release
      default:
        return nil
    }
  }
}

// MARK: - Network Errors

/// Errors related to network operations
public enum NetworkError: Error, LocalizedError, Sendable {
  /// A network request failed
  case requestFailed(String)

  /// The GitHub API returned an invalid or unexpected response
  case invalidResponse

  /// The GitHub API rate limit was exceeded
  case rateLimitExceeded

  public var errorDescription: String? {
    String(localized: "A network error occurred.", bundle: .module)
  }

  public var failureReason: String? {
    switch self {
      case .requestFailed(let message):
        return String(
          localized: "The network request failed: \(message)",
          bundle: .module
        )
      case .invalidResponse:
        return String(
          localized: "The GitHub API returned an invalid or unexpected response.",
          bundle: .module
        )
      case .rateLimitExceeded:
        return String(
          localized: "The GitHub API rate limit of 60 requests per hour has been exceeded.",
          bundle: .module
        )
    }
  }

  public var recoverySuggestion: String? {
    switch self {
      case .requestFailed:
        return String(
          localized: "Check your internet connection and try again.",
          bundle: .module
        )
      case .invalidResponse:
        return String(
          localized: "Try again later. If the problem persists, the GitHub API may have changed.",
          bundle: .module
        )
      case .rateLimitExceeded:
        return String(
          localized: "Wait a few minutes before trying again.",
          bundle: .module
        )
    }
  }
}

// MARK: - Repository Errors

/// Errors related to repository operations
public enum RepositoryError: Error, LocalizedError, Sendable {
  /// The specified repository was not found
  case notFound

  /// No releases were found for the repository
  case noReleasesFound

  public var errorDescription: String? {
    String(localized: "A repository error occurred.", bundle: .module)
  }

  public var failureReason: String? {
    switch self {
      case .notFound:
        return String(
          localized: "The specified repository could not be found on GitHub.",
          bundle: .module
        )
      case .noReleasesFound:
        return String(
          localized: "No releases were found for this repository.",
          bundle: .module
        )
    }
  }

  public var recoverySuggestion: String? {
    switch self {
      case .notFound:
        return String(
          localized:
            "Verify the repository owner and name are correct, and that the repository is public.",
          bundle: .module
        )
      case .noReleasesFound:
        return nil
    }
  }
}

// MARK: - Version Errors

/// Errors related to version parsing
public enum VersionError: Error, LocalizedError, Sendable {
  /// The version string could not be parsed
  case invalidVersion

  public var errorDescription: String? {
    String(localized: "A version error occurred.", bundle: .module)
  }

  public var failureReason: String? {
    String(
      localized: "The version string in the release tag could not be parsed.",
      bundle: .module
    )
  }

  public var recoverySuggestion: String? {
    nil
  }
}

// MARK: - Download Errors

/// Errors related to file downloads
public enum DownloadError: Error, LocalizedError, Sendable {
  /// The download failed
  case failed(String)

  /// The download was cancelled by the user
  case cancelled

  public var errorDescription: String? {
    String(localized: "A download error occurred.", bundle: .module)
  }

  public var failureReason: String? {
    switch self {
      case .failed(let message):
        return String(
          localized: "The file download failed: \(message)",
          bundle: .module
        )
      case .cancelled:
        return String(
          localized: "The download was cancelled by the user.",
          bundle: .module
        )
    }
  }

  public var recoverySuggestion: String? {
    switch self {
      case .failed:
        return String(
          localized: "Check your internet connection and try again.",
          bundle: .module
        )
      case .cancelled:
        return nil
    }
  }
}

// MARK: - Legacy UpdateCheckError (for backwards compatibility)

/// Errors that can occur when checking for or downloading updates.
///
/// - Note: This enum is maintained for backwards compatibility. Consider using
///   the more specific error types: ``NetworkError``, ``RepositoryError``,
///   ``VersionError``, or ``DownloadError``.
public enum UpdateCheckError: Error, LocalizedError, Sendable {
  /// A network error occurred.
  case networkError(String)

  /// The GitHub API returned an invalid or unexpected response.
  case invalidResponse

  /// No releases were found for the repository.
  case noReleasesFound

  /// The GitHub API rate limit was exceeded.
  case rateLimitExceeded

  /// The specified repository was not found.
  case repositoryNotFound

  /// The version string could not be parsed.
  case invalidVersion

  /// The download failed.
  case downloadFailed(String)

  /// The operation was cancelled by the user.
  case cancelled

  public var errorDescription: String? {
    switch self {
      case .networkError, .invalidResponse, .rateLimitExceeded:
        return String(localized: "A network error occurred.", bundle: .module)
      case .noReleasesFound, .repositoryNotFound:
        return String(localized: "A repository error occurred.", bundle: .module)
      case .invalidVersion:
        return String(localized: "A version error occurred.", bundle: .module)
      case .downloadFailed, .cancelled:
        return String(localized: "A download error occurred.", bundle: .module)
    }
  }

  public var failureReason: String? {
    switch self {
      case .networkError(let message):
        return String(
          localized: "The network request failed: \(message)",
          bundle: .module
        )
      case .invalidResponse:
        return String(
          localized: "The GitHub API returned an invalid or unexpected response.",
          bundle: .module
        )
      case .noReleasesFound:
        return String(
          localized: "No releases were found for this repository.",
          bundle: .module
        )
      case .rateLimitExceeded:
        return String(
          localized: "The GitHub API rate limit of 60 requests per hour has been exceeded.",
          bundle: .module
        )
      case .repositoryNotFound:
        return String(
          localized: "The specified repository could not be found on GitHub.",
          bundle: .module
        )
      case .invalidVersion:
        return String(
          localized: "The version string in the release tag could not be parsed.",
          bundle: .module
        )
      case .downloadFailed(let message):
        return String(
          localized: "The file download failed: \(message)",
          bundle: .module
        )
      case .cancelled:
        return String(
          localized: "The operation was cancelled by the user.",
          bundle: .module
        )
    }
  }

  public var recoverySuggestion: String? {
    switch self {
      case .networkError, .downloadFailed:
        return String(
          localized: "Check your internet connection and try again.",
          bundle: .module
        )
      case .invalidResponse:
        return String(
          localized: "Try again later. If the problem persists, the GitHub API may have changed.",
          bundle: .module
        )
      case .rateLimitExceeded:
        return String(
          localized: "Wait a few minutes before trying again.",
          bundle: .module
        )
      case .repositoryNotFound:
        return String(
          localized:
            "Verify the repository owner and name are correct, and that the repository is public.",
          bundle: .module
        )
      case .noReleasesFound, .invalidVersion, .cancelled:
        return nil
    }
  }
}
