#if os(macOS)
  import AppKit
  import Foundation

  /// Observable model for the update alert view
  @Observable
  @MainActor
  public final class UpdateAlertModel {
    // Configuration
    var release: GitHubRelease?
    var currentVersion = SemanticVersion(major: 0)
    var appName: String = ""
    var appIcon = NSImage()

    // State
    var state: UpdateAlertState = .idle
    var downloadProgress = DownloadProgressModel()
    var installProgress = InstallProgressModel()

    // Callbacks
    var onDownload: () -> Void = {}
    var onSkip: () -> Void = {}
    var onRemindLater: () -> Void = {}
    var onDismiss: () -> Void = {}
    var onRevealInFinder: (URL) -> Void = { _ in }
    var onInstall: (URL) -> Void = { _ in }
    var onRestartNow: () -> Void = {}
    var onRestartLater: () -> Void = {}

    // MARK: - Initialization

    /// Creates a new update alert model
    public init() {}

    // MARK: - Configuration

    func configure(
      release: GitHubRelease,
      currentVersion: SemanticVersion,
      appName: String,
      appIcon: NSImage,
      onDownload: @escaping () -> Void,
      onSkip: @escaping () -> Void,
      onRemindLater: @escaping () -> Void,
      onDismiss: @escaping () -> Void
    ) {
      self.release = release
      self.currentVersion = currentVersion
      self.appName = appName
      self.appIcon = appIcon
      self.state = .idle
      self.onDownload = onDownload
      self.onSkip = onSkip
      self.onRemindLater = onRemindLater
      self.onDismiss = onDismiss
    }

    func startDownload(fileName: String, onCancel: @escaping () -> Void) {
      state = .downloading
      downloadProgress.update(
        fileName: fileName,
        progress: 0,
        downloadedBytes: nil,
        totalBytes: nil,
        timeRemaining: nil,
        onCancel: onCancel
      )
    }

    func updateProgress(
      fileName: String,
      progress: Double,
      downloadedBytes: Measurement<UnitInformationStorage>?,
      totalBytes: Measurement<UnitInformationStorage>?,
      timeRemaining: TimeInterval?,
      onCancel: @escaping () -> Void
    ) {
      downloadProgress.update(
        fileName: fileName,
        progress: progress,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        timeRemaining: timeRemaining,
        onCancel: onCancel
      )
    }

    func completeDownload(fileName: String, fileURL: URL) {
      state = .complete(fileName: fileName, fileURL: fileURL)
    }

    func showError(_ message: String) {
      state = .error(ErrorInfo(description: message, failureReason: nil, recoverySuggestion: nil))
    }

    func showError(_ error: some LocalizedError) {
      state = .error(ErrorInfo(from: error))
    }

    func reset() {
      state = .idle
    }

    // MARK: - Installation Methods

    func startInstallation(onCancel: @escaping () -> Void) {
      state = .installing(phase: .preparing, message: "Preparing...")
      installProgress.update(phase: .preparing, message: "Preparing...", onCancel: onCancel)
    }

    func updateInstallProgress(phase: InstallPhase, message: String, onCancel: @escaping () -> Void)
    {
      state = .installing(phase: phase, message: message)
      installProgress.update(phase: phase, message: message, onCancel: onCancel)
    }

    func completeInstallation(appURL: URL) {
      state = .installComplete(appURL: appURL)
    }
  }

  /// State for the update alert view
  enum UpdateAlertState: Equatable {
    case idle
    case downloading
    case complete(fileName: String, fileURL: URL)
    case installing(phase: InstallPhase, message: String)
    case installComplete(appURL: URL)
    case error(ErrorInfo)

    static func == (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
        case (.idle, .idle), (.downloading, .downloading):
          return true
        case let (.complete(lName, lURL), .complete(rName, rURL)):
          return lName == rName && lURL == rURL
        case let (.installing(lPhase, lMsg), .installing(rPhase, rMsg)):
          return lPhase == rPhase && lMsg == rMsg
        case let (.installComplete(lURL), .installComplete(rURL)):
          return lURL == rURL
        case let (.error(lInfo), .error(rInfo)):
          return lInfo == rInfo
        default:
          return false
      }
    }
  }

  /// Structured error information for display
  struct ErrorInfo: Equatable {
    /// General category description of the error
    let description: String

    /// Instance-specific details about the error
    let failureReason: String?

    /// Actionable instructions for the user
    let recoverySuggestion: String?

    init(description: String, failureReason: String?, recoverySuggestion: String?) {
      self.description = description
      self.failureReason = failureReason
      self.recoverySuggestion = recoverySuggestion
    }

    init(from error: some LocalizedError) {
      self.description = error.errorDescription ?? "An error occurred."
      self.failureReason = error.failureReason
      self.recoverySuggestion = error.recoverySuggestion
    }
  }
#endif
