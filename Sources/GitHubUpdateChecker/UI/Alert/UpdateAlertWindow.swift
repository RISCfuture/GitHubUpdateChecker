#if os(macOS)
  public import AppKit
  import Observation
  import SwiftUI

  /// Manages the update alert window presentation
  @MainActor
  public final class UpdateAlertWindowController {
    // MARK: - Type Properties

    /// Shared instance
    public static let shared = UpdateAlertWindowController()

    // MARK: - Instance Properties

    private var window: NSWindow?
    private var updateAlertModel: UpdateAlertModel?
    private var stateObserver: Task<Void, Never>?
    private weak var parentChecker: GitHubUpdateChecker?

    /// The current update alert model (for external progress updates)
    var currentModel: UpdateAlertModel? { updateAlertModel }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Show the update alert for a release
    /// - Parameters:
    ///   - release: The available release
    ///   - currentVersion: The current app version
    ///   - checker: The parent update checker (for installation callbacks)
    ///   - onDownload: Called when user clicks Download
    ///   - onSkip: Called when user clicks Skip This Version
    ///   - onRemindLater: Called when user clicks Remind Me Later
    public func showUpdateAlert(
      release: GitHubRelease,
      currentVersion: SemanticVersion,
      checker: GitHubUpdateChecker? = nil,
      onDownload: @escaping () -> Void,
      onSkip: @escaping () -> Void,
      onRemindLater: @escaping () -> Void
    ) {
      dismiss()

      self.parentChecker = checker

      let appName = Bundle.main.appName
      let appIcon = NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName)!

      let model = UpdateAlertModel()
      model.configure(
        release: release,
        currentVersion: currentVersion,
        appName: appName,
        appIcon: appIcon,
        onDownload: onDownload,
        onSkip: { [weak self] in
          onSkip()
          self?.dismiss()
        },
        onRemindLater: { [weak self] in
          onRemindLater()
          self?.dismiss()
        },
        onDismiss: { [weak self] in
          self?.dismiss()
        }
      )
      model.onRevealInFinder = { [weak self] url in
        UpdateDownloader.revealInFinder(url)
        self?.dismiss()
      }
      model.onInstall = { [weak self] fileURL in
        Task { @MainActor in
          await self?.parentChecker?.installUpdate(from: fileURL)
        }
      }
      model.onRestartNow = { [weak self] in
        self?.parentChecker?.relaunchApp()
      }
      model.onRestartLater = { [weak self] in
        self?.dismiss()
      }

      updateAlertModel = model
      showWindow(for: model)
      observeClosability(of: model)
    }

    /// Show the "no updates available" alert
    /// - Parameter currentVersion: The current app version
    public func showNoUpdatesAvailable(currentVersion: SemanticVersion) {
      let appName = Bundle.main.appName

      let alert = NSAlert()
      alert.messageText = "\(appName) is up to date"
      alert.informativeText =
        "You’re running version \(currentVersion), which is the latest version available."
      alert.alertStyle = .informational
      alert.addButton(withTitle: "OK")
      alert.runModal()
    }

    /// Show an error alert for update check errors
    /// - Parameter error: The error to display
    public func showError(_ error: UpdateCheckError) {
      showErrorAlert(error)
    }

    /// Show an error alert for installation errors
    /// - Parameter error: The error to display
    public func showError(_ error: some InstallationError) {
      showErrorAlert(error)
    }

    /// Show an error alert for any LocalizedError
    /// - Parameter error: The error to display
    public func showErrorAlert(_ error: some LocalizedError) {
      let alert = NSAlert()

      // Use errorDescription as the message text (general category)
      alert.messageText = error.errorDescription ?? "An error occurred."

      // Build informative text from failureReason and recoverySuggestion
      var informativeText = ""
      if let failureReason = error.failureReason {
        informativeText = failureReason
      }
      if let recoverySuggestion = error.recoverySuggestion {
        if !informativeText.isEmpty {
          informativeText += "\n\n"
        }
        informativeText += recoverySuggestion
      }
      alert.informativeText = informativeText

      alert.alertStyle = .warning
      alert.addButton(withTitle: "OK")
      alert.runModal()
    }

    /// Dismiss the current window
    public func dismiss() {
      stateObserver?.cancel()
      stateObserver = nil
      window?.close()
      window = nil
      updateAlertModel = nil
    }

    // MARK: - Private Methods

    /// Keep the close button in step with the model, for as long as the alert is on screen.
    ///
    /// The window keeps its size and content through every state and the SwiftUI view inside follows
    /// the model on its own, so the style mask is the controller's only per-state concern.
    private func observeClosability(of model: UpdateAlertModel) {
      stateObserver?.cancel()
      stateObserver = Task { [weak self] in
        for await state in Observations({ model.state }) {
          guard let self else { return }
          window?.isClosable = state.allowsClosing
        }
      }
    }

    private func showWindow(for model: UpdateAlertModel) {
      let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: UpdateAlertView.contentSize),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
      )

      window.contentView = NSHostingView(rootView: UpdateAlertView(model: model))
      window.title = "Software Update"
      window.isReleasedWhenClosed = false
      window.center()
      window.makeKeyAndOrderFront(nil)

      // Bring app to front
      NSApp.activate(ignoringOtherApps: true)

      self.window = window
    }
  }

  // MARK: - NSWindow Extension

  extension NSWindow {
    /// Whether the window's close button is enabled.
    fileprivate var isClosable: Bool {
      get { styleMask.contains(.closable) }
      set {
        if newValue {
          styleMask.insert(.closable)
        } else {
          styleMask.remove(.closable)
        }
      }
    }
  }

  // MARK: - Bundle Extension

  extension Bundle {
    /// The application name from the bundle
    var appName: String {
      object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "Application"
    }

    /// The application version string (CFBundleShortVersionString)
    var appVersion: String? {
      object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
  }
#endif
