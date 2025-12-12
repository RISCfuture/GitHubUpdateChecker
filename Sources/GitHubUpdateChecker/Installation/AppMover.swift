#if os(macOS)
  import AppKit
  import Foundation
  import Logging

  /// Handles moving the application to the Applications folder on first launch
  @MainActor
  public enum AppMover {
    private static let logger = Logger(label: "codes.tim.GitHubUpdateChecker.AppMover")

    // MARK: - Public Properties

    /// Whether the app is currently located in an Applications folder
    public static var isInApplicationsFolder: Bool {
      let bundlePath = Bundle.main.bundlePath

      // Check against known Applications directories
      let applicationDirectories = FileManager.default.urls(
        for: .applicationDirectory,
        in: .allDomainsMask
      )

      for directory in applicationDirectories where bundlePath.hasPrefix(directory.path) {
        return true
      }

      // Also check for /Applications directly (in case FileManager doesn't return it)
      if bundlePath.hasPrefix("/Applications/") {
        return true
      }

      return false
    }

    // MARK: - Private Properties

    /// Check if the app is running from a read-only volume
    private static var isOnReadOnlyVolume: Bool {
      let bundleURL = Bundle.main.bundleURL
      let parentDirectory = bundleURL.deletingLastPathComponent()

      // Check if we can write to the parent directory
      return !FileManager.default.isWritableFile(atPath: parentDirectory.path)
    }

    // MARK: - Public Methods

    /// Check if the app should be moved to Applications and prompt the user if appropriate.
    ///
    /// Call this method early in your app's launch sequence, typically in
    /// `applicationDidFinishLaunching` or at the start of your SwiftUI `App.init()`.
    ///
    /// The prompt will only appear if:
    /// - The app is not already in an Applications folder
    /// - The app is not sandboxed
    /// - The app is not running from a read-only volume (e.g., a DMG)
    /// - The user has not previously declined to move the app
    ///
    /// If the user agrees to move, the app will be copied to the Applications folder,
    /// the original will be moved to Trash, and the app will relaunch from the new location.
    public static func moveToApplicationsFolderIfNeeded() {
      logger.info(
        "Checking if app should be moved to Applications",
        metadata: [
          "bundlePath": "\(Bundle.main.bundlePath)",
          "isInApplicationsFolder": "\(isInApplicationsFolder)",
          "isSandboxed": "\(AppInstaller.isSandboxed)",
          "isOnReadOnlyVolume": "\(isOnReadOnlyVolume)",
          "userDeclined": "\(UpdatePreferences.shared.userDeclinedMoveToApplications)"
        ]
      )

      // Skip if already in Applications
      guard !isInApplicationsFolder else {
        logger.debug("App is already in Applications folder, skipping move prompt")
        return
      }

      // Skip if sandboxed (can't move ourselves)
      guard !AppInstaller.isSandboxed else {
        logger.debug("App is sandboxed, skipping move prompt")
        return
      }

      // Skip if running from read-only volume (e.g., DMG)
      guard !isOnReadOnlyVolume else {
        logger.debug("App is on read-only volume, skipping move prompt")
        return
      }

      // Skip if user previously declined
      guard !UpdatePreferences.shared.userDeclinedMoveToApplications else {
        logger.debug("User previously declined move, skipping prompt")
        return
      }

      logger.info("Prompting user to move app to Applications folder")

      // Show the move prompt
      let response = showMoveAlert()

      if response == .alertFirstButtonReturn {
        // User chose to move
        performMove()
      } else {
        // User declined - remember this choice
        logger.info("User declined to move app to Applications folder")
        UpdatePreferences.shared.userDeclinedMoveToApplications = true
      }
    }

    // MARK: - Private Methods

    /// Show the alert asking the user to move the app
    private static func showMoveAlert() -> NSApplication.ModalResponse {
      let appName = Bundle.main.appName

      let alert = NSAlert()
      alert.messageText = String(
        localized: "Move to Applications folder?",
        comment: "Title of alert asking user to move app to Applications folder"
      )
      alert.informativeText = String(
        localized:
          "\(appName) is not in your Applications folder. Would you like to move it there?",
        comment: "Message explaining why the app should be moved to Applications folder"
      )
      alert.alertStyle = .informational

      alert.addButton(
        withTitle: String(
          localized: "Move to Applications",
          comment: "Button to move the app to Applications folder"
        )
      )
      alert.addButton(
        withTitle: String(
          localized: "Don’t Move",
          comment: "Button to decline moving the app to Applications folder"
        )
      )

      // Bring the app to the front
      NSApp.activate(ignoringOtherApps: true)

      return alert.runModal()
    }

    /// Perform the move operation
    private static func performMove() {
      let sourceURL = Bundle.main.bundleURL
      let appName = sourceURL.lastPathComponent

      // Determine the best destination directory
      guard let destinationDirectory = preferredInstallDirectory() else {
        logger.error("Could not determine destination Applications directory")
        showErrorAlert(
          message: String(
            localized: "Could not find the Applications folder.",
            comment: "Error message when Applications folder cannot be found"
          )
        )
        return
      }

      let destinationURL = destinationDirectory.appendingPathComponent(appName)

      logger.info(
        "Moving app to Applications folder",
        metadata: [
          "source": "\(sourceURL.path)",
          "destination": "\(destinationURL.path)"
        ]
      )

      do {
        // Check if destination needs elevated privileges
        if PrivilegeEscalation.requiresElevation(for: destinationURL) {
          try moveWithElevation(from: sourceURL, to: destinationURL)
        } else {
          try moveWithoutElevation(from: sourceURL, to: destinationURL)
        }

        // Remove quarantine attribute from the moved app
        removeQuarantineAttribute(from: destinationURL)

        logger.info("App moved successfully, relaunching from new location")

        // Relaunch from the new location
        AppRelaunch.relaunchApp(appURL: destinationURL)
      } catch {
        logger.error(
          "Failed to move app",
          metadata: ["error": "\(error.localizedDescription)"]
        )
        showErrorAlert(
          message: String(
            localized: "Failed to move the application: \(error.localizedDescription)",
            comment: "Error message when app move fails"
          )
        )
      }
    }

    /// Move without elevation (destination is writable)
    private static func moveWithoutElevation(from source: URL, to destination: URL) throws {
      let fileManager = FileManager.default

      // Remove existing app at destination if present
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }

      // Copy to destination
      try fileManager.copyItem(at: source, to: destination)

      // Trash the original
      try fileManager.trashItem(at: source, resultingItemURL: nil)
    }

    /// Move with elevated privileges (destination requires admin)
    private static func moveWithElevation(from source: URL, to destination: URL) throws {
      // Use PrivilegeEscalation to copy with admin privileges
      try PrivilegeEscalation.copyWithElevatedPrivileges(from: source, to: destination)

      // Trash the original (this shouldn't need elevation)
      try FileManager.default.trashItem(at: source, resultingItemURL: nil)
    }

    /// Find the preferred Applications directory
    ///
    /// Returns the Applications folder that contains the most apps,
    /// preferring /Applications over ~/Applications in case of a tie.
    private static func preferredInstallDirectory() -> URL? {
      let fileManager = FileManager.default

      // Get both local (/Applications) and user (~/Applications) directories
      var candidates: [URL] = []

      if let localApps = fileManager.urls(for: .applicationDirectory, in: .localDomainMask).first {
        candidates.append(localApps)
      }

      if let userApps = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first {
        candidates.append(userApps)
      }

      guard !candidates.isEmpty else { return nil }

      // Count apps in each directory and return the one with more apps
      // In case of tie, prefer the first one (local /Applications)
      return candidates.max { countApps(in: $0) < countApps(in: $1) }
    }

    /// Count the number of .app bundles in a directory
    private static func countApps(in directory: URL) -> Int {
      let fileManager = FileManager.default

      guard
        let contents = try? fileManager.contentsOfDirectory(
          at: directory,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )
      else {
        return 0
      }

      return contents.filter { $0.pathExtension == "app" }.count
    }

    /// Remove the quarantine extended attribute from a file
    private static func removeQuarantineAttribute(from url: URL) {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
      process.arguments = ["-rd", "com.apple.quarantine", url.path]

      do {
        try process.run()
        process.waitUntilExit()
        logger.debug("Removed quarantine attribute from app")
      } catch {
        // Non-fatal, just log
        logger.warning(
          "Failed to remove quarantine attribute",
          metadata: ["error": "\(error.localizedDescription)"]
        )
      }
    }

    /// Show an error alert
    private static func showErrorAlert(message: String) {
      let alert = NSAlert()
      alert.messageText = String(
        localized: "Unable to Move Application",
        comment: "Title of error alert when app move fails"
      )
      alert.informativeText = message
      alert.alertStyle = .warning
      alert.addButton(withTitle: String(localized: "OK", comment: "The label of an OK button."))
      alert.runModal()
    }
  }
#endif
