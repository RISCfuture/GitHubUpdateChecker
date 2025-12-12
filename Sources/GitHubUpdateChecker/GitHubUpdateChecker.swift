import Foundation
import Logging
#if os(macOS)
  import AppKit
#endif

/// Main entry point for the GitHub update checker
///
/// Use this class to check for updates from a GitHub repository's releases.
///
/// ## Basic Usage
///
/// ```swift
/// let checker = GitHubUpdateChecker(owner: "username", repo: "myapp")
///
/// // Start automatic background checks
/// checker.startAutomaticChecks()
///
/// // Or check manually
/// Task {
///     await checker.checkForUpdatesAndShowUI()
/// }
/// ```
///
/// ## Menu Bar Integration
///
/// ```swift
/// .commands {
///     CommandGroup(after: .appInfo) {
///         Button("Check for Updates...") {
///             Task { await checker.checkForUpdatesAndShowUI() }
///         }
///         .disabled(!checker.canCheckForUpdates)
///     }
/// }
/// ```
@MainActor
@Observable
public final class GitHubUpdateChecker {
  // MARK: - Configuration

  /// The GitHub repository owner (username or organization)
  public let owner: String

  /// The GitHub repository name
  public let repo: String

  /// The current app version (defaults to CFBundleShortVersionString)
  public let currentVersion: SemanticVersion

  /// Optional regex pattern to match a specific asset (e.g., ".*\\.dmg$")
  public var assetPattern: String?

  // MARK: - State

  /// Whether an update check can be started (false while checking)
  public private(set) var canCheckForUpdates: Bool = true

  /// The timestamp of the last successful update check
  public private(set) var lastCheckDate: Date? {
    get { preferences.lastCheckTimestamp }
    set { preferences.lastCheckTimestamp = newValue }
  }

  /// The latest release found (if any)
  public private(set) var latestRelease: GitHubRelease?

  /// Whether a download is in progress
  public private(set) var isDownloading: Bool = false

  /// Current download progress (0.0 to 1.0)
  public private(set) var downloadProgress: Double = 0

  /// The URL of the most recently downloaded file (for custom UI integration)
  public private(set) var downloadedFileURL: URL?

  /// Whether an installation is in progress
  public private(set) var isInstalling: Bool = false

  /// Current installation phase description (for custom UI integration)
  public private(set) var installationPhase: String?

  /// The URL of the installed app after successful installation (for custom UI integration)
  public private(set) var installedAppURL: URL?

  // MARK: - Dependencies

  /// The preferences instance
  public let preferences: UpdatePreferences

  private let apiClient: GitHubAPIClient
  private let downloader: UpdateDownloader
  private let installer = AppInstaller()
  private var scheduler: UpdateScheduler?
  private let logger = Logger(label: "codes.tim.GitHubUpdateChecker")

  #if os(macOS)
    private let windowController: UpdateAlertWindowController
  #endif

  // MARK: - Initialization

  /// Creates a new update checker
  /// - Parameters:
  ///   - owner: The GitHub repository owner
  ///   - repo: The GitHub repository name
  ///   - currentVersion: The current app version (defaults to bundle version)
  ///   - preferences: The preferences instance to use
  public init(
    owner: String,
    repo: String,
    currentVersion: SemanticVersion? = nil,
    preferences: UpdatePreferences = .shared
  ) {
    self.owner = owner
    self.repo = repo
    self.currentVersion =
      currentVersion ?? SemanticVersion(Bundle.main.appVersion ?? "0.0.0")
      ?? SemanticVersion(major: 0, minor: 0, patch: 0)
    self.preferences = preferences
    self.apiClient = GitHubAPIClient()
    self.downloader = UpdateDownloader()

    #if os(macOS)
      self.windowController = UpdateAlertWindowController.shared
    #endif

    logger.info(
      "Initialized update checker",
      metadata: [
        "owner": "\(owner)",
        "repo": "\(repo)",
        "currentVersion": "\(self.currentVersion)"
      ]
    )
  }

  // MARK: - Public API

  /// Start automatic background update checks based on the configured cadence
  public func startAutomaticChecks() {
    scheduler = UpdateScheduler(preferences: preferences) { [weak self] in
      await self?.performSilentCheck()
    }
    scheduler?.start()
  }

  /// Stop automatic background update checks
  public func stopAutomaticChecks() {
    scheduler?.stop()
    scheduler = nil
  }

  /// Check for updates silently and return the result
  /// - Returns: The result of the update check
  public func checkForUpdates() async throws -> UpdateCheckResult {
    guard canCheckForUpdates else {
      logger.debug("Update check skipped - already checking")
      return .error(.cancelled)
    }

    logger.info(
      "Checking for updates",
      metadata: [
        "includePrereleases": "\(preferences.checkForPrereleases)"
      ]
    )

    canCheckForUpdates = false
    defer { canCheckForUpdates = true }

    do {
      let release = try await apiClient.fetchLatestRelease(
        owner: owner,
        repo: repo,
        includePrereleases: preferences.checkForPrereleases
      )

      latestRelease = release
      lastCheckDate = Date()

      // Check if this version should be shown
      guard let releaseVersion = release.version, releaseVersion > currentVersion else {
        logger.info(
          "No update available",
          metadata: [
            "currentVersion": "\(currentVersion)",
            "latestVersion": "\(release.version?.description ?? release.tagName)"
          ]
        )
        return .noUpdateAvailable
      }

      // Check if user has skipped this version
      if preferences.isVersionSkipped(releaseVersion) {
        logger.info(
          "Update available but skipped by user",
          metadata: [
            "version": "\(releaseVersion)"
          ]
        )
        return .skippedVersion(release)
      }

      logger.info(
        "Update available",
        metadata: [
          "currentVersion": "\(currentVersion)",
          "newVersion": "\(releaseVersion)",
          "prerelease": "\(release.prerelease)"
        ]
      )
      return .updateAvailable(release)
    } catch let error as UpdateCheckError {
      logger.error(
        "Update check failed",
        metadata: [
          "error": "\(error.localizedDescription)"
        ]
      )
      return .error(error)
    } catch {
      logger.error(
        "Update check failed with unexpected error",
        metadata: [
          "error": "\(error.localizedDescription)"
        ]
      )
      return .error(.networkError(error.localizedDescription))
    }
  }

  /// Check for updates and show the appropriate UI
  ///
  /// Shows an alert if an update is available, or a "you're up to date" message if not.
  public func checkForUpdatesAndShowUI() async {
    #if os(macOS)
      let result = try? await checkForUpdates()

      switch result {
        case .updateAvailable(let release):
          showUpdateAlert(for: release)

        case .noUpdateAvailable, .skippedVersion:
          windowController.showNoUpdatesAvailable(currentVersion: currentVersion)

        case .error(let error):
          windowController.showError(error)

        case .none:
          windowController.showError(.networkError("Unknown error"))
      }
    #endif
  }

  /// Show the update alert for a specific release
  /// - Parameter release: The release to show
  public func showUpdateAlert(for release: GitHubRelease) {
    #if os(macOS)
      logger.debug(
        "Showing update alert",
        metadata: [
          "tagName": "\(release.tagName)",
          "version": "\(release.version?.description ?? "unknown")"
        ]
      )

      windowController.showUpdateAlert(
        release: release,
        currentVersion: currentVersion,
        checker: self,
        onDownload: { [weak self] in
          Task { @MainActor in
            await self?.downloadUpdate(release)
          }
        },
        onSkip: { [weak self] in
          if let version = release.version {
            self?.logger.info(
              "User skipped version",
              metadata: [
                "version": "\(version)"
              ]
            )
            self?.preferences.skipVersion(version)
          }
        },
        onRemindLater: { [weak self] in
          self?.logger.debug("User chose remind later")
        }
      )
    #endif
  }

  /// Download an update
  /// - Parameter release: The release to download
  public func downloadUpdate(_ release: GitHubRelease) async {
    #if os(macOS)
      guard let asset = selectAsset(from: release) else {
        logger.error(
          "No downloadable asset found for release",
          metadata: [
            "tagName": "\(release.tagName)",
            "assetCount": "\(release.assets.count)"
          ]
        )
        windowController.showError(.downloadFailed("No downloadable asset found"))
        return
      }

      // Determine download destination based on app capabilities
      let destinationURL: URL
      switch UpdateDownloader.downloadCapability {
        case .directAccess:
          // App has direct Downloads access
          let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
            .first!
          destinationURL = downloadsDir.appendingPathComponent(asset.name)
          logger.debug(
            "Using direct Downloads access",
            metadata: [
              "destination": "\(destinationURL.path(percentEncoded: false))"
            ]
          )

        case .savePanel:
          // Need to prompt user with NSSavePanel
          logger.debug("Using save panel for download location")
          guard let selectedURL = await UpdateDownloader.promptForSaveLocation(fileName: asset.name)
          else {
            logger.info("User cancelled save panel")
            return
          }
          destinationURL = selectedURL
          logger.debug(
            "User selected save location",
            metadata: [
              "destination": "\(destinationURL.path(percentEncoded: false))"
            ]
          )

        case .browserOnly:
          // No file write capability, open in browser instead
          logger.info(
            "No download entitlements, opening asset URL in browser",
            metadata: [
              "url": "\(asset.browserDownloadURL)"
            ]
          )
          NSWorkspace.shared.open(asset.browserDownloadURL)
          return
      }

      logger.info(
        "Starting update download",
        metadata: [
          "tagName": "\(release.tagName)",
          "assetName": "\(asset.name)",
          "assetSize": "\(asset.size)"
        ]
      )

      isDownloading = true
      downloadProgress = 0

      // Model is optional - when using custom UI, there may be no model
      let model = windowController.currentModel

      // Start download progress in built-in UI if available
      model?.startDownload(fileName: asset.name) { [weak self] in
        Task {
          await self?.downloader.cancelDownload()
          await MainActor.run {
            self?.isDownloading = false
            model?.reset()
          }
        }
      }

      do {
        let fileURL = try await downloader.download(
          asset: asset,
          to: destinationURL.deletingLastPathComponent(),
          onProgress: { [weak self] progress in
            Task { @MainActor [weak self] in
              guard let self else { return }
              self.downloadProgress = progress.fractionCompleted
              model?.updateProgress(
                fileName: asset.name,
                progress: progress.fractionCompleted,
                downloadedBytes: Measurement(value: Double(progress.bytesWritten), unit: .bytes),
                totalBytes: Measurement(value: Double(progress.totalBytes), unit: .bytes),
                timeRemaining: progress.estimatedTimeRemaining,
                onCancel: { [weak self] in
                  Task {
                    await self?.downloader.cancelDownload()
                    await MainActor.run {
                      self?.isDownloading = false
                      model?.reset()
                    }
                  }
                }
              )
            }
          }
        )

        isDownloading = false
        downloadProgress = 1.0
        downloadedFileURL = fileURL

        // Show completion in built-in UI if available
        model?.completeDownload(fileName: asset.name, fileURL: fileURL)

        logger.info(
          "Download completed",
          metadata: [
            "fileName": "\(asset.name)",
            "fileURL": "\(fileURL.path(percentEncoded: false))"
          ]
        )
      } catch {
        isDownloading = false

        if case UpdateCheckError.cancelled = error {
          model?.reset()
          return
        }

        model?.showError(error.localizedDescription)
        logger.error(
          "Download failed",
          metadata: [
            "error": "\(error.localizedDescription)"
          ]
        )
      }
    #endif
  }

  /// Cancel any ongoing download
  public func cancelDownload() async {
    await downloader.cancelDownload()
    isDownloading = false
  }

  /// Install a downloaded update
  /// - Parameters:
  ///   - fileURL: The downloaded DMG or ZIP file
  ///   - targetAppURL: Where to install (defaults to current app location)
  public func installUpdate(from fileURL: URL, to targetAppURL: URL? = nil) async {
    #if os(macOS)
      guard !isInstalling else {
        logger.debug("Installation skipped - already installing")
        return
      }

      guard canAutoInstall(fileURL: fileURL) else {
        logger.error("Cannot auto-install file", metadata: ["path": "\(fileURL.path)"])
        let error = GeneralInstallationError.unsupportedFileType(fileURL.pathExtension)
        windowController.currentModel?.showError(error)
        return
      }

      logger.info(
        "Starting update installation",
        metadata: [
          "fileURL": "\(fileURL.path)",
          "targetAppURL": "\(targetAppURL?.path ?? "current app")"
        ]
      )

      isInstalling = true

      // Model is optional - when using custom UI, there may be no model
      let model = windowController.currentModel

      // Start installation progress UI if available
      model?.startInstallation { [weak self] in
        Task {
          await self?.installer.cancelInstallation()
          await MainActor.run {
            self?.isInstalling = false
            model?.reset()
          }
        }
      }

      do {
        let installedURL = try await installer.install(
          from: fileURL,
          to: targetAppURL,
          onProgress: { [weak self] progress in
            Task { @MainActor [weak self] in
              guard let self else { return }
              self.installationPhase = progress.phase.displayName
              model?.updateInstallProgress(
                phase: progress.phase,
                message: progress.message,
                onCancel: { [weak self] in
                  Task {
                    await self?.installer.cancelInstallation()
                    await MainActor.run {
                      self?.isInstalling = false
                      model?.reset()
                    }
                  }
                }
              )
            }
          }
        )

        isInstalling = false
        installedAppURL = installedURL
        logger.info(
          "Installation completed successfully",
          metadata: [
            "installedURL": "\(installedURL.path)"
          ]
        )

        // Show restart prompt in built-in UI if available
        model?.completeInstallation(appURL: installedURL)
      } catch {
        isInstalling = false

        if case GeneralInstallationError.cancelled = error {
          logger.info("Installation cancelled by user")
          model?.reset()
          return
        }

        logger.error(
          "Installation failed",
          metadata: [
            "error": "\(error.localizedDescription)"
          ]
        )

        // Show structured error if it conforms to InstallationError protocol
        if let installError = error as? (any InstallationError) {
          model?.showError(installError)
        } else {
          model?.showError(error.localizedDescription)
        }
      }
    #endif
  }

  /// Check if a downloaded file can be automatically installed
  /// - Parameter fileURL: The downloaded file URL
  /// - Returns: true if the file type supports auto-installation
  public func canAutoInstall(fileURL: URL) -> Bool {
    let ext = fileURL.pathExtension.lowercased()
    return AppInstaller.supportsAutoInstall && (ext == "dmg" || ext == "zip")
  }

  /// Relaunch the application after an update
  /// - Parameter appURL: The URL of the app to launch (defaults to current app)
  public func relaunchApp(appURL: URL? = nil) {
    #if os(macOS)
      logger.info("Relaunching application")
      AppRelaunch.relaunchApp(appURL: appURL)
    #endif
  }

  // MARK: - Private

  private func performSilentCheck() async {
    let result = try? await checkForUpdates()

    #if os(macOS)
      if case .updateAvailable(let release) = result {
        showUpdateAlert(for: release)
      }
    #endif
  }

  private func selectAsset(from release: GitHubRelease) -> GitHubAsset? {
    // If a pattern is specified, use it
    if let pattern = assetPattern {
      return release.asset(matching: pattern)
    }

    // Otherwise use the primary asset detection
    return release.primaryAsset
  }
}

// MARK: - Convenience Extensions

public extension GitHubUpdateChecker {
  /// Whether automatic update checking is currently active
  var isAutomaticCheckingEnabled: Bool {
    scheduler?.isRunning ?? false
  }

  /// The URL to the releases page on GitHub
  var releasesURL: URL {
    URL(string: "https://github.com/\(owner)/\(repo)/releases")!
  }

  /// Open the GitHub releases page in the default browser
  func openReleasesPage() {
    #if os(macOS)
      NSWorkspace.shared.open(releasesURL)
    #endif
  }
}
