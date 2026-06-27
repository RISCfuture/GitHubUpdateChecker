#if os(macOS)
  import AppKit
  import Foundation
  import Logging

  /// Handles installing updates by replacing the current app bundle
  public actor AppInstaller {
    // MARK: - Type Properties

    /// Check if automatic installation is supported
    /// - Returns: true if the app can perform automatic installations
    public static var supportsAutoInstall: Bool {
      // Sandboxed apps cannot perform automatic installations
      !isSandboxed
    }

    /// Check if the current app is sandboxed
    public static var isSandboxed: Bool {
      ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    // MARK: - Instance Properties

    private let logger = Logger(label: "codes.tim.GitHubUpdateChecker.AppInstaller")
    private let dmgHandler = DMGHandler()
    private let zipHandler = ZIPHandler()

    /// The current installation task, if any
    private var currentTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new app installer
    public init() {}

    // MARK: - Public API

    /// Install an update from a downloaded file
    ///
    /// The returned stream yields each installation phase and finishes once the app is installed at
    /// `installedURL`. If installation fails or is cancelled, the stream finishes by throwing the
    /// underlying error (`GeneralInstallationError`, `DiskImageError`, `ArchiveError`,
    /// `FileCopyError`, `AuthorizationError`, `VerificationError`, or a `CancellationError`).
    /// - Parameters:
    ///   - fileURL: The downloaded DMG or ZIP file
    ///   - targetAppURL: Where to install (defaults to current app location)
    /// - Returns: An async throwing stream of installation progress and the installed app URL
    /// - Throws: `GeneralInstallationError.unsupportedFileType` if the file cannot be auto-installed
    public func install(
      from fileURL: URL,
      to targetAppURL: URL? = nil
    ) throws -> (progress: AsyncThrowingStream<InstallProgress, Error>, installedURL: URL) {
      // Detect file type
      guard let installableType = detectType(from: fileURL) else {
        throw GeneralInstallationError.unsupportedFileType(fileURL.pathExtension)
      }

      guard installableType.supportsAutoInstall else {
        throw GeneralInstallationError.unsupportedFileType(fileURL.pathExtension)
      }

      // Determine target location
      let destination = targetAppURL ?? currentAppURL()

      logger.info(
        "Starting installation",
        metadata: [
          "source": "\(fileURL.path)",
          "destination": "\(destination.path)",
          "type": "\(installableType)"
        ]
      )

      let (stream, continuation) = AsyncThrowingStream<InstallProgress, Error>.makeStream()

      let installTask = Task { [weak self] in
        guard let self else {
          continuation.finish()
          return
        }
        do {
          try await self.performInstall(
            from: fileURL,
            type: installableType,
            to: destination,
            onProgress: { continuation.yield($0) }
          )
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }

      currentTask = installTask

      return (stream, destination)
    }

    /// Cancel any ongoing installation
    public func cancelInstallation() {
      currentTask?.cancel()
      currentTask = nil
      logger.info("Installation cancelled")
    }

    /// Detect the installable type from a file URL
    /// - Parameter url: The file URL to check
    /// - Returns: The installable type, or nil if not supported
    public func detectType(from url: URL) -> InstallableType? {
      let ext = url.pathExtension.lowercased()
      return [InstallableType.dmg, .zip, .pkg].first { $0.fileExtensions.contains(ext) }
    }

    // MARK: - Private Methods

    private func performInstall(
      from fileURL: URL,
      type: InstallableType,
      to destination: URL,
      onProgress: @escaping @Sendable (InstallProgress) -> Void
    ) async throws {
      // Report preparing
      onProgress(InstallProgress(phase: .preparing, message: "Preparing installation..."))

      // Extract/mount and get the .app URL
      let (appURL, cleanup) = try await extractApp(
        from: fileURL,
        type: type,
        onProgress: onProgress
      )

      defer {
        // Always run cleanup
        Task {
          await cleanup()
        }
      }

      // Copy to destination
      onProgress(InstallProgress(phase: .copying, message: "Installing update..."))
      let installedURL = try await copyApp(from: appURL, to: destination)

      // Verify installation
      onProgress(InstallProgress(phase: .verifying, message: "Verifying installation..."))
      try verifyInstallation(at: installedURL)

      // Cleanup phase
      onProgress(InstallProgress(phase: .cleaning, message: "Cleaning up..."))

      // Complete
      onProgress(InstallProgress(phase: .complete, message: "Installation complete"))

      logger.info(
        "Installation completed successfully",
        metadata: [
          "installedApp": "\(installedURL.path)"
        ]
      )
    }

    /// Extract an app from a DMG or ZIP file
    /// - Returns: A tuple of (app URL, cleanup closure)
    private func extractApp(
      from fileURL: URL,
      type: InstallableType,
      onProgress: @escaping @Sendable (InstallProgress) -> Void
    ) async throws -> (URL, @Sendable () async -> Void) {
      switch type {
        case .dmg:
          onProgress(InstallProgress(phase: .mounting, message: "Opening disk image..."))
          let mountPoint = try await dmgHandler.mount(dmgURL: fileURL)

          let appURL = try await dmgHandler.findApp(in: mountPoint)

          let cleanup: @Sendable () async -> Void = { [dmgHandler] in
            do {
              try await dmgHandler.unmount(mountPoint: mountPoint)
            } catch {
              // Log but don't fail - unmount failure is non-fatal
            }
          }

          return (appURL, cleanup)

        case .zip:
          onProgress(InstallProgress(phase: .extracting, message: "Extracting update..."))
          let appURL = try await zipHandler.extract(zipURL: fileURL)

          // The extraction directory is the parent of the app
          let extractionDir = appURL.deletingLastPathComponent()

          let cleanup: @Sendable () async -> Void = { [zipHandler] in
            await zipHandler.cleanup(directory: extractionDir)
          }

          return (appURL, cleanup)

        case .pkg:
          throw GeneralInstallationError.unsupportedFileType("pkg")
      }
    }

    /// Copy an app to the destination, handling privilege escalation if needed
    private func copyApp(from source: URL, to destination: URL) async throws -> URL {
      let fileManager = FileManager.default

      logger.debug(
        "Copying app",
        metadata: [
          "source": "\(source.path)",
          "destination": "\(destination.path)"
        ]
      )

      // Check if we need elevated privileges
      if PrivilegeEscalation.requiresElevation(for: destination) {
        logger.info("Elevated privileges required for installation")
        try await PrivilegeEscalation.copyWithElevatedPrivileges(from: source, to: destination)
      } else {
        // Standard copy
        do {
          // Remove existing app if present
          if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
          }

          // Copy new app
          try fileManager.copyItem(at: source, to: destination)
        } catch {
          logger.error(
            "Failed to copy app",
            metadata: [
              "error": "\(error.localizedDescription)"
            ]
          )
          throw FileCopyError.copyFailed(error.localizedDescription)
        }
      }

      // Remove quarantine attribute from the installed app
      await removeQuarantineAttribute(from: destination)

      return destination
    }

    /// Verify that the installed app is valid
    private func verifyInstallation(at url: URL) throws {
      let fileManager = FileManager.default

      // Check that the app bundle exists
      guard fileManager.fileExists(atPath: url.path) else {
        throw VerificationError.failed("Application not found at destination")
      }

      // Check for Contents/MacOS directory
      let macOSDir = url.appendingPathComponent("Contents/MacOS")
      var isDirectory: ObjCBool = false
      guard fileManager.fileExists(atPath: macOSDir.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        throw VerificationError.failed("Invalid application bundle structure")
      }

      // Check for Info.plist
      let infoPlist = url.appendingPathComponent("Contents/Info.plist")
      guard fileManager.fileExists(atPath: infoPlist.path) else {
        throw VerificationError.failed("Missing Info.plist")
      }

      logger.debug("Installation verified successfully")
    }

    /// Get the URL of the currently running application
    private func currentAppURL() -> URL {
      Bundle.main.bundleURL
    }

    /// Remove the quarantine extended attribute from a file
    private func removeQuarantineAttribute(from url: URL) async {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
      process.arguments = ["-rd", "com.apple.quarantine", url.path]

      do {
        try await process.runUntilExit()
        logger.debug("Removed quarantine attribute from app")
      } catch {
        // Non-fatal, just log
        logger.warning(
          "Failed to remove quarantine attribute",
          metadata: [
            "error": "\(error.localizedDescription)"
          ]
        )
      }
    }
  }
#endif
