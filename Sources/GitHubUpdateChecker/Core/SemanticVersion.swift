import Foundation

/// A semantic version following the semver specification.
///
/// `SemanticVersion` represents versions in the format `MAJOR.MINOR.PATCH`
/// with optional prerelease identifiers. It conforms to `Comparable` for
/// natural version ordering and `Codable` for serialization.
///
/// ## Usage
///
/// ```swift
/// let v1 = SemanticVersion("1.2.3")
/// let v2 = SemanticVersion("2.0.0")
///
/// if v1 < v2 {
///     print("Update available!")
/// }
/// ```
///
/// ## String Parsing
///
/// The parser handles common version formats:
/// - Standard: `1.0.0`, `2.1.3`
/// - With `v` prefix: `v1.0.0`, `V2.0`
/// - With "version" prefix: `version 1.0`
/// - Partial versions: `1.0`, `1` (missing components default to 0)
/// - Prerelease: `1.0.0-beta`, `2.0.0-rc.1` (prerelease suffix is stored but
///   currently not compared)
public struct SemanticVersion: Sendable, Equatable, Hashable {
  /// The major version component.
  public let major: Int

  /// The minor version component.
  public let minor: Int

  /// The patch version component.
  public let patch: Int

  /// Optional prerelease identifier (e.g., "beta", "rc.1").
  public let prerelease: String?

  /// Creates a semantic version with the given components.
  /// - Parameters:
  ///   - major: The major version number.
  ///   - minor: The minor version number (default: 0).
  ///   - patch: The patch version number (default: 0).
  ///   - prerelease: Optional prerelease identifier.
  public init(major: Int, minor: Int = 0, patch: Int = 0, prerelease: String? = nil) {
    self.major = major
    self.minor = minor
    self.patch = patch
    self.prerelease = prerelease
  }

  /// Creates a semantic version by parsing a version string.
  ///
  /// Returns `nil` if the string cannot be parsed as a valid version.
  ///
  /// - Parameter string: The version string to parse.
  public init?(_ string: String) {
    guard let parsed = Self.parse(string) else { return nil }
    self = parsed
  }

  // MARK: - Private

  private static func parse(_ string: String) -> Self? {
    var normalized = string.trimmingCharacters(in: .whitespaces)

    // Remove 'version' prefix first (case insensitive)
    if normalized.lowercased().hasPrefix("version") {
      normalized = String(normalized.dropFirst(7)).trimmingCharacters(in: .whitespaces)
    }
    // Remove 'v' or 'V' prefix
    else if normalized.lowercased().hasPrefix("v") {
      normalized = String(normalized.dropFirst())
    }

    // Guard against empty string
    guard !normalized.isEmpty else { return nil }

    // Split off prerelease suffix (everything after first hyphen)
    let prereleaseComponents = normalized.split(separator: "-", maxSplits: 1)
    guard let firstComponent = prereleaseComponents.first else { return nil }
    let versionPart = String(firstComponent)
    let prerelease = prereleaseComponents.count > 1 ? String(prereleaseComponents[1]) : nil

    // Parse version components
    let parts = versionPart.split(separator: ".")
    guard !parts.isEmpty else { return nil }

    // Extract numeric values from each part
    var components: [Int] = []
    for part in parts {
      // Take leading digits only (handles cases like "1b" -> 1)
      let numericPrefix = part.prefix(while: \.isNumber)
      guard let value = Int(numericPrefix), !numericPrefix.isEmpty else {
        if components.isEmpty { return nil }
        break
      }
      components.append(value)
    }

    guard !components.isEmpty else { return nil }

    return Self(
      major: components[0],
      minor: components.count > 1 ? components[1] : 0,
      patch: components.count > 2 ? components[2] : 0,
      prerelease: prerelease
    )
  }
}

// MARK: - Comparable

extension SemanticVersion: Comparable {
  public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
    if lhs.major != rhs.major { return lhs.major < rhs.major }
    if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
    return lhs.patch < rhs.patch
  }
}

// MARK: - CustomStringConvertible

extension SemanticVersion: CustomStringConvertible {
  public var description: String {
    var result = "\(major).\(minor).\(patch)"
    if let prerelease {
      result += "-\(prerelease)"
    }
    return result
  }
}

// MARK: - LosslessStringConvertible

extension SemanticVersion: LosslessStringConvertible {}

// MARK: - Codable

extension SemanticVersion: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    guard let version = SemanticVersion(string) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid semantic version string: \(string)"
      )
    }
    self = version
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}
