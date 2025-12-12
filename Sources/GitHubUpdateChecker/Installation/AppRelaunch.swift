#if os(macOS)
  import AppKit
  import Foundation
  import Logging

  /// Logger for AppRelaunch - declared outside class to be nonisolated
  private let appRelaunchLogger = Logger(label: "codes.tim.GitHubUpdateChecker.AppRelaunch")

  /// Handles relaunching the application after an update
  @MainActor
  public enum AppRelaunch {

    /// Tracks whether a relaunch has already been initiated
    private static var isRelaunching = false

    /// Relaunch the application
    /// - Parameters:
    ///   - appURL: The URL of the app to launch (defaults to current app)
    ///   - afterDelay: Delay before relaunch (allows current app to quit)
    public static func relaunchApp(appURL: URL? = nil, afterDelay: TimeInterval = 1.0) {
      // Prevent multiple calls
      guard !isRelaunching else {
        appRelaunchLogger.debug("Relaunch already in progress, ignoring")
        return
      }
      isRelaunching = true

      let targetURL = appURL ?? Bundle.main.bundleURL

      appRelaunchLogger.info(
        "Preparing to relaunch app",
        metadata: [
          "appURL": "\(targetURL.path)",
          "delay": "\(afterDelay)"
        ]
      )

      // Use a shell script to wait and then open the app
      // This allows the current app to fully quit before relaunching
      let script = """
        sleep \(afterDelay)
        open "\(targetURL.path.escapedForShell)"
        """

      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/bin/sh")
      process.arguments = ["-c", script]

      // Detach from current process so it survives app termination
      process.standardOutput = nil
      process.standardError = nil
      process.standardInput = nil

      do {
        try process.run()
        appRelaunchLogger.info("Relaunch script started")
      } catch {
        appRelaunchLogger.error(
          "Failed to start relaunch script",
          metadata: [
            "error": "\(error.localizedDescription)"
          ]
        )
        isRelaunching = false
        return
      }

      // Terminate the current app
      terminateApp()
    }

    /// Terminate the current application
    public static func terminateApp() {
      appRelaunchLogger.info("Terminating application")
      // Use exit() for immediate termination - NSApplication.terminate() can be blocked
      exit(0)
    }

    /// Open the app at the specified URL without terminating the current app
    /// - Parameter url: The URL of the app to open
    public static func openApp(at url: URL) {
      appRelaunchLogger.info("Opening app", metadata: ["url": "\(url.path)"])

      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = true

      NSWorkspace.shared.openApplication(
        at: url,
        configuration: configuration
      ) { _, error in
        if let error {
          appRelaunchLogger.error(
            "Failed to open app",
            metadata: [
              "error": "\(error.localizedDescription)"
            ]
          )
        } else {
          appRelaunchLogger.info("App opened successfully")
        }
      }
    }
  }
#endif
