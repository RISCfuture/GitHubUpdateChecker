#if os(macOS)
  import AppKit
  import SwiftUI

  /// Manages the update alert window presentation
  @MainActor
  public final class UpdateAlertWindowController {
    // MARK: - Type Properties

    /// Shared instance
    public static let shared = UpdateAlertWindowController()

    // MARK: - Instance Properties

    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    private var updateAlertModel: UpdateAlertModel?
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

      let view = UpdateAlertView(model: model)
      showWindow(with: AnyView(view), title: "Software Update", closable: true)

      // Observe state changes to swap windows
      observeModelState(model)
    }

    /// Show the "no updates available" alert
    /// - Parameter currentVersion: The current app version
    public func showNoUpdatesAvailable(currentVersion: SemanticVersion) {
      let appName = Bundle.main.appName

      let alert = NSAlert()
      alert.messageText = "\(appName) is up to date"
      alert.informativeText =
        "You're running version \(currentVersion), which is the latest version available."
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
      window?.close()
      window = nil
      hostingView = nil
      updateAlertModel = nil
    }

    // MARK: - Private Methods

    private func observeModelState(_ model: UpdateAlertModel) {
      startObserving(model)
    }

    private func startObserving(_ model: UpdateAlertModel) {
      withObservationTracking {
        _ = model.state
      } onChange: { [weak self] in
        Task { @MainActor [weak self] in
          guard let self else { return }
          self.handleStateChange(model.state)
          self.startObserving(model)
        }
      }
    }

    private func handleStateChange(_ state: UpdateAlertState) {
      guard let model = updateAlertModel else { return }

      switch state {
        case .idle:
          // Show the main update alert view
          let view = UpdateAlertView(model: model)
          replaceWindowContent(with: AnyView(view), title: "Software Update", closable: true)

        case .downloading:
          let view = DownloadProgressView(model: model.downloadProgress)
          replaceWindowContent(with: AnyView(view), title: "", closable: false)

        case let .complete(fileName, fileURL):
          let canInstall = canAutoInstall(fileURL: fileURL)
          let view = DownloadCompleteView(
            fileName: fileName,
            fileURL: fileURL,
            canInstall: canInstall,
            onRevealInFinder: {
              model.onRevealInFinder(fileURL)
            },
            onInstall: {
              model.onInstall(fileURL)
            },
            onClose: {
              model.onDismiss()
            }
          )
          replaceWindowContent(with: AnyView(view), title: "", closable: true)

        case .installing:
          let view = InstallProgressView(model: model.installProgress)
          replaceWindowContent(with: AnyView(view), title: "", closable: false)

        case .installComplete:
          let view = RestartPromptView(
            appName: model.appName,
            newVersion: model.release?.version?.description ?? "Unknown",
            onRestartNow: model.onRestartNow,
            onRestartLater: {
              model.onRestartLater()
              model.onDismiss()
            }
          )
          replaceWindowContent(with: AnyView(view), title: "", closable: true)

        case let .error(errorInfo):
          let view = ErrorAlertView(
            errorInfo: errorInfo,
            onDismiss: {
              model.reset()
            }
          )
          replaceWindowContent(with: AnyView(view), title: "", closable: true)
      }
    }

    private func canAutoInstall(fileURL: URL) -> Bool {
      let ext = fileURL.pathExtension.lowercased()
      return AppInstaller.supportsAutoInstall && (ext == "dmg" || ext == "zip")
    }

    private func replaceWindowContent(with view: AnyView, title: String, closable: Bool) {
      let newHostingView = NSHostingView(rootView: view)
      newHostingView.setContentHuggingPriority(.required, for: .horizontal)
      newHostingView.setContentHuggingPriority(.required, for: .vertical)

      if let window {
        // Update existing window
        window.contentView = newHostingView
        window.title = title

        // Update style mask for closable
        var styleMask: NSWindow.StyleMask = [.titled]
        if closable {
          styleMask.insert(.closable)
        }
        window.styleMask = styleMask

        window.setContentSize(newHostingView.fittingSize)
        hostingView = newHostingView
      } else {
        // Create new window
        showWindow(with: view, title: title, closable: closable)
      }
    }

    private func showWindow(with view: AnyView, title: String, closable: Bool) {
      let hostingView = NSHostingView(rootView: view)
      hostingView.setContentHuggingPriority(.required, for: .horizontal)
      hostingView.setContentHuggingPriority(.required, for: .vertical)

      var styleMask: NSWindow.StyleMask = [.titled]
      if closable {
        styleMask.insert(.closable)
      }

      let window = NSWindow(
        contentRect: .zero,
        styleMask: styleMask,
        backing: .buffered,
        defer: false
      )

      window.contentView = hostingView
      window.title = title
      window.isReleasedWhenClosed = false
      window.setContentSize(hostingView.fittingSize)
      window.center()
      window.makeKeyAndOrderFront(nil)

      // Bring app to front
      NSApp.activate(ignoringOtherApps: true)

      self.window = window
      self.hostingView = hostingView
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

    /// The build number (CFBundleVersion)
    var buildNumber: String? {
      object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
  }
#endif
