import Foundation

/// A GitHub release from the Releases API.
///
/// This struct represents the data returned by GitHub's
/// [Releases API](https://docs.github.com/en/rest/releases/releases).
/// It contains metadata about the release including version information,
/// release notes, and downloadable assets.
///
/// ## Usage
///
/// You typically receive `GitHubRelease` instances from ``UpdateCheckResult``:
///
/// ```swift
/// let result = try await checker.checkForUpdates()
/// if case .updateAvailable(let release) = result {
///     print("New version: \(release.version)")
///     print("Release notes: \(release.body ?? "None")")
///
///     if let asset = release.primaryAsset {
///         print("Download: \(asset.browserDownloadURL)")
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Release Information
///
/// - ``id``
/// - ``tagName``
/// - ``version``
/// - ``name``
/// - ``body``
/// - ``htmlURL``
/// - ``publishedAt``
///
/// ### Release Status
///
/// - ``prerelease``
/// - ``draft``
///
/// ### Assets
///
/// - ``assets``
/// - ``primaryAsset``
/// - ``asset(matching:)``
public struct GitHubRelease: Codable, Sendable, Identifiable {
  /// The unique identifier for this release.
  public let id: Int

  /// The git tag associated with this release (e.g., "v1.2.0").
  public let tagName: String

  /// The human-readable title of the release.
  public let name: String?

  /// The release notes in Markdown format.
  public let body: String?

  /// URL to the release page on GitHub.
  public let htmlURL: URL

  /// When this release was published.
  public let publishedAt: Date?

  /// Downloadable files attached to this release.
  public let assets: [GitHubAsset]

  /// Whether this is a prerelease version.
  public let prerelease: Bool

  /// Whether this release is a draft (not publicly visible).
  public let draft: Bool

  /// The semantic version parsed from the tag name.
  ///
  /// This property parses the tag name into a ``SemanticVersion``, stripping
  /// common prefixes like "v" or "version".
  /// For example, a tag of "v1.2.0" returns `SemanticVersion(1, 2, 0)`.
  ///
  /// Returns `nil` if the tag cannot be parsed as a valid version.
  public var version: SemanticVersion? {
    SemanticVersion(tagName)
  }

  /// Returns the first asset matching common macOS app distribution formats.
  ///
  /// This property searches for assets in the following order:
  /// 1. `.dmg` files (disk images)
  /// 2. `.zip` files (compressed archives)
  /// 3. `.pkg` files (installer packages)
  ///
  /// If none of these are found, returns the first available asset.
  public var primaryAsset: GitHubAsset? {
    let preferredExtensions = [".dmg", ".zip", ".pkg"]
    for ext in preferredExtensions {
      if let asset = assets.first(where: { $0.name.lowercased().hasSuffix(ext) }) {
        return asset
      }
    }
    return assets.first
  }

  /// Returns an asset matching the given regex pattern.
  ///
  /// Use this method when you need to select a specific asset from releases
  /// that contain multiple downloadable files.
  ///
  /// ```swift
  /// // Match ARM64-specific DMG
  /// let asset = release.asset(matching: ".*-arm64\\.dmg$")
  ///
  /// // Match Intel-specific ZIP
  /// let asset = release.asset(matching: ".*-x86_64\\.zip$")
  /// ```
  ///
  /// - Parameter pattern: A regular expression pattern to match against asset names.
  /// - Returns: The first asset whose name matches the pattern, or `nil` if none match.
  public func asset(matching pattern: String) -> GitHubAsset? {
    guard let regex = try? Regex(pattern) else { return nil }
    return assets.first { $0.name.contains(regex) }
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case tagName = "tag_name"
    case name
    case body
    case htmlURL = "html_url"
    case publishedAt = "published_at"
    case assets
    case prerelease
    case draft
  }
}

/// A downloadable file attached to a GitHub release.
///
/// Assets represent the actual files users can download from a release,
/// such as `.dmg` disk images, `.zip` archives, or `.pkg` installers.
///
/// ## Topics
///
/// ### Asset Information
///
/// - ``id``
/// - ``name``
/// - ``browserDownloadURL``
/// - ``size``
/// - ``formattedSize``
/// - ``contentType``
/// - ``downloadCount``
public struct GitHubAsset: Codable, Sendable, Identifiable {
  /// The unique identifier for this asset.
  public let id: Int

  /// The filename of the asset (e.g., "MyApp-1.0.0.dmg").
  public let name: String

  /// Direct download URL for the asset.
  ///
  /// This URL can be used to download the asset without authentication
  /// for public repositories.
  public let browserDownloadURL: URL

  /// File size in bytes.
  public let size: Int

  /// MIME type of the asset (e.g., "application/octet-stream").
  public let contentType: String

  /// Number of times this asset has been downloaded.
  public let downloadCount: Int

  /// Human-readable file size string.
  ///
  /// Returns the file size formatted appropriately (e.g., "15.2 MB", "1.5 GB").
  public var formattedSize: String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(size))
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case browserDownloadURL = "browser_download_url"
    case size
    case contentType = "content_type"
    case downloadCount = "download_count"
  }
}
