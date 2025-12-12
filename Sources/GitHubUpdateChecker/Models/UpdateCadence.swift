import Foundation

/// Defines how frequently the app should check for updates.
///
/// Use this enum with ``UpdatePreferences/updateCadence`` to control
/// automatic update checking behavior.
///
/// ## Example
///
/// ```swift
/// // Check for updates daily
/// UpdatePreferences.shared.updateCadence = .daily
///
/// // Disable automatic checks
/// UpdatePreferences.shared.updateCadence = .never
/// ```
///
/// ## Topics
///
/// ### Cases
///
/// - ``hourly``
/// - ``daily``
/// - ``weekly``
/// - ``never``
///
/// ### Properties
///
/// - ``timeInterval``
/// - ``displayName``
public enum UpdateCadence: String, Codable, CaseIterable, Sendable {
  /// Check for updates every hour (3600 seconds).
  case hourly

  /// Check for updates every day (86400 seconds).
  case daily

  /// Check for updates every week (604800 seconds).
  case weekly

  /// Disable automatic update checking.
  ///
  /// When set to `.never`, automatic background checks are disabled,
  /// but users can still manually check via
  /// ``GitHubUpdateChecker/GitHubUpdateChecker/checkForUpdatesAndShowUI()``.
  case never

  /// The time interval between checks in seconds.
  ///
  /// Returns `nil` for ``never``, indicating automatic checks are disabled.
  public var timeInterval: TimeInterval? {
    switch self {
      case .hourly: return 3600
      case .daily: return 86400
      case .weekly: return 604800
      case .never: return nil
    }
  }

  /// Human-readable display name for use in settings UI.
  ///
  /// Returns localized strings: "Hourly", "Daily", "Weekly", or "Never".
  public var displayName: String {
    switch self {
      case .hourly: return "Hourly"
      case .daily: return "Daily"
      case .weekly: return "Weekly"
      case .never: return "Never"
    }
  }
}
