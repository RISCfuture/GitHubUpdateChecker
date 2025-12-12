import Foundation

/// Keys used for storing preferences in UserDefaults
private enum UserDefaultsKeys {
  static let prefix = "codes.tim.GitHubUpdateChecker."

  static let updateCadence = prefix + "updateCadence"
  static let automaticDownload = prefix + "automaticDownload"
  static let lastCheckTimestamp = prefix + "lastCheckTimestamp"
  static let skippedVersions = prefix + "skippedVersions"
  static let checkForPrereleases = prefix + "checkForPrereleases"
}

/// Manages user preferences for update checking behavior.
///
/// `UpdatePreferences` provides persistent storage for user settings related
/// to update checking. All preferences are stored in `UserDefaults` with the
/// prefix `tim.codes.GitHubUpdateChecker.`.
///
/// ## Usage
///
/// Access the shared instance for most use cases:
///
/// ```swift
/// let prefs = UpdatePreferences.shared
/// prefs.updateCadence = .weekly
/// prefs.checkForPrereleases = true
/// ```
///
/// ## Building a Settings UI
///
/// Since `UpdatePreferences` is `@Observable`, you can use it directly in SwiftUI:
///
/// ```swift
/// struct SettingsView: View {
///     let prefs = UpdatePreferences.shared
///
///     var body: some View {
///         Picker("Check for updates", selection: $prefs.updateCadence) {
///             ForEach(UpdateCadence.allCases, id: \.self) { cadence in
///                 Text(cadence.displayName).tag(cadence)
///             }
///         }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Getting the Shared Instance
///
/// - ``shared``
///
/// ### Update Checking Settings
///
/// - ``updateCadence``
/// - ``checkForPrereleases``
/// - ``automaticDownload``
///
/// ### Tracking State
///
/// - ``lastCheckTimestamp``
/// - ``skippedVersions``
///
/// ### Managing Skipped Versions
///
/// - ``skipVersion(_:)``
/// - ``isVersionSkipped(_:)``
/// - ``resetSkippedVersions()``
///
/// ### Resetting
///
/// - ``resetToDefaults()``
@MainActor
@Observable
public final class UpdatePreferences {
  /// The shared preferences instance using standard `UserDefaults`.
  public static let shared = UpdatePreferences()

  private let defaults: UserDefaults

  /// How frequently to check for updates
  public var updateCadence: UpdateCadence {
    didSet {
      defaults.set(updateCadence.rawValue, forKey: UserDefaultsKeys.updateCadence)
    }
  }

  /// Whether to automatically download updates when found
  public var automaticDownload: Bool {
    didSet {
      defaults.set(automaticDownload, forKey: UserDefaultsKeys.automaticDownload)
    }
  }

  /// The timestamp of the last update check
  public var lastCheckTimestamp: Date? {
    didSet {
      if let timestamp = lastCheckTimestamp {
        defaults.set(timestamp.timeIntervalSince1970, forKey: UserDefaultsKeys.lastCheckTimestamp)
      } else {
        defaults.removeObject(forKey: UserDefaultsKeys.lastCheckTimestamp)
      }
    }
  }

  /// Set of versions the user has chosen to skip
  public var skippedVersions: Set<SemanticVersion> {
    didSet {
      let strings = skippedVersions.map(\.description)
      defaults.set(strings, forKey: UserDefaultsKeys.skippedVersions)
    }
  }

  /// Whether to include pre-release versions when checking for updates
  public var checkForPrereleases: Bool {
    didSet {
      defaults.set(checkForPrereleases, forKey: UserDefaultsKeys.checkForPrereleases)
    }
  }

  /// Creates a new preferences instance
  /// - Parameter defaults: The UserDefaults instance to use for storage
  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults

    // Load initial values from defaults
    if let cadenceString = defaults.string(forKey: UserDefaultsKeys.updateCadence),
      let cadence = UpdateCadence(rawValue: cadenceString)
    {
      self.updateCadence = cadence
    } else {
      self.updateCadence = .daily
    }

    self.automaticDownload = defaults.bool(forKey: UserDefaultsKeys.automaticDownload)

    if defaults.object(forKey: UserDefaultsKeys.lastCheckTimestamp) != nil {
      let timestamp = defaults.double(forKey: UserDefaultsKeys.lastCheckTimestamp)
      self.lastCheckTimestamp = Date(timeIntervalSince1970: timestamp)
    } else {
      self.lastCheckTimestamp = nil
    }

    if let skipped = defaults.stringArray(forKey: UserDefaultsKeys.skippedVersions) {
      self.skippedVersions = Set(skipped.compactMap { SemanticVersion($0) })
    } else {
      self.skippedVersions = []
    }

    self.checkForPrereleases = defaults.bool(forKey: UserDefaultsKeys.checkForPrereleases)
  }

  /// Mark a version as skipped so it won't trigger update alerts
  /// - Parameter version: The version to skip
  public func skipVersion(_ version: SemanticVersion) {
    skippedVersions.insert(version)
  }

  /// Check if a version has been skipped by the user
  /// - Parameter version: The version to check
  /// - Returns: true if the version should be skipped
  public func isVersionSkipped(_ version: SemanticVersion) -> Bool {
    skippedVersions.contains(version)
  }

  /// Clear all skipped versions
  public func resetSkippedVersions() {
    skippedVersions.removeAll()
  }

  /// Reset all preferences to defaults
  public func resetToDefaults() {
    updateCadence = .daily
    automaticDownload = false
    lastCheckTimestamp = nil
    skippedVersions = []
    checkForPrereleases = false
  }
}
