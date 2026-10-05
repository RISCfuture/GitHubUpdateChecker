#if os(macOS)
  import AppKit
  import SwiftUI

  /// The update alert: a fixed-size dialog whose header and release notes stay put while the
  /// bottom strip follows the model's state through download, installation, and restart.
  struct UpdateAlertView: View {
    /// The size of the window content, sized like Sparkle's update alert.
    static let contentSize = CGSize(width: 620, height: 370)

    private static let iconSize: CGFloat = 64
    private static let margin: CGFloat = 20

    var model: UpdateAlertModel

    var body: some View {
      HStack(alignment: .top, spacing: Self.margin) {
        if let release = model.release {
          Image(nsImage: model.appIcon)
            .resizable()
            .scaledToFit()
            .frame(width: Self.iconSize, height: Self.iconSize)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 12) {
            UpdateAlertHeader(
              appName: model.appName,
              newVersion: release.version ?? SemanticVersion(major: 0),
              currentVersion: model.currentVersion
            )

            ReleaseNotesSection(release: release)

            UpdateAlertFooter(model: model)
          }
        }
      }
      .padding(Self.margin)
      .frame(width: Self.contentSize.width, height: Self.contentSize.height)
    }
  }

  // MARK: - Header

  struct UpdateAlertHeader: View {
    let appName: String
    let newVersion: SemanticVersion
    let currentVersion: SemanticVersion

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text("A new version of \(appName) is available.")
          .font(.headline)

        Text(
          "\(appName) \(newVersion.description) is now available. You have version \(currentVersion.description)."
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Release Notes

  private struct ReleaseNotesSection: View {
    let release: GitHubRelease

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text("Release Notes:")
          .bold()

        ReleaseNotesView(release: release)
      }
    }
  }

  // MARK: - Footer

  /// The strip beneath the release notes, which holds whichever controls the current state needs.
  ///
  /// Its height has a floor so that moving between states does not shift the release notes; only
  /// an error long enough to need the room grows it.
  struct UpdateAlertFooter: View {
    private static let minHeight: CGFloat = 44

    var model: UpdateAlertModel

    var body: some View {
      Group {
        switch model.state {
          case .idle:
            UpdateAlertButtons(
              onSkip: model.onSkip,
              onRemindLater: model.onRemindLater,
              onDownload: model.onDownload
            )

          case .downloading:
            DownloadProgressView(model: model.downloadProgress)

          case let .complete(fileName, fileURL):
            DownloadCompleteView(
              fileName: fileName,
              canInstall: AppInstaller.canAutoInstall(fileURL: fileURL),
              onRevealInFinder: { model.onRevealInFinder(fileURL) },
              onInstall: { model.onInstall(fileURL) },
              onClose: model.onDismiss
            )

          case .installing:
            InstallProgressView(model: model.installProgress)

          case .installComplete:
            RestartPromptView(
              appName: model.appName,
              newVersion: model.release?.version?.description ?? "Unknown",
              onRestartNow: model.onRestartNow,
              onRestartLater: {
                model.onRestartLater()
                model.onDismiss()
              }
            )

          case let .error(errorInfo):
            ErrorAlertView(errorInfo: errorInfo, onDismiss: model.reset)
        }
      }
      .frame(maxWidth: .infinity, minHeight: Self.minHeight)
    }
  }

  // MARK: - Buttons

  struct UpdateAlertButtons: View {
    let onSkip: () -> Void
    let onRemindLater: () -> Void
    let onDownload: () -> Void

    var body: some View {
      HStack {
        Button("Skip This Version") { onSkip() }

        Spacer()

        Button("Remind Me Later") { onRemindLater() }
          .keyboardShortcut(.cancelAction)

        Button("Download Update") { onDownload() }
          .keyboardShortcut(.defaultAction)
      }
    }
  }

  // MARK: - Previews

  extension UpdateAlertModel {
    // periphery:ignore - referenced only from #Preview bodies, whose expansions are not indexed
    /// A configured model parked in `state`, for rendering the alert without a real download.
    static func preview(in state: UpdateAlertState) -> UpdateAlertModel {
      let model = UpdateAlertModel()
      model.configure(
        release: GitHubRelease(
          id: 1,
          tagName: "v2.0.0",
          name: "Version 2.0.0",
          body: """
            ## What's New

            - **New Feature**: Added dark mode support
            - **Improvement**: Better performance, especially on launch, when the window list is \
            rebuilt from the saved state and every entry is checked against the running apps.
            - **Bug Fix**: Fixed crash on startup

            ### Breaking Changes

            None in this release.
            """,
          htmlURL: URL(string: "https://github.com/example/app/releases/tag/v2.0.0")!,
          publishedAt: Date().addingTimeInterval(-86400),
          assets: [],
          prerelease: false,
          draft: false
        ),
        currentVersion: SemanticVersion(major: 1, minor: 5, patch: 0),
        appName: "My App",
        appIcon: NSApp.applicationIconImage,
        onDownload: {},
        onSkip: {},
        onRemindLater: {},
        onDismiss: {}
      )
      switch state {
        case .downloading:
          model.updateProgress(
            fileName: "MyApp-2.0.0.dmg",
            progress: 0.45,
            downloadedBytes: Measurement(value: 12.5, unit: .megabytes),
            totalBytes: Measurement(value: 28.0, unit: .megabytes),
            timeRemaining: 154,
            onCancel: {}
          )
        case let .installing(phase, message):
          model.installProgress.update(phase: phase, message: message, onCancel: {})
        case .idle, .complete, .installComplete, .error:
          break
      }
      model.state = state
      return model
    }
  }

  #Preview("Idle") {
    UpdateAlertView(model: .preview(in: .idle))
  }

  #Preview("Downloading") {
    UpdateAlertView(model: .preview(in: .downloading))
  }

  #Preview("Download Complete") {
    UpdateAlertView(
      model: .preview(
        in: .complete(fileName: "MyApp-2.0.0.dmg", fileURL: URL(filePath: "/tmp/MyApp-2.0.0.dmg"))
      )
    )
  }

  #Preview("Installing") {
    UpdateAlertView(
      model: .preview(in: .installing(phase: .mounting, message: "Opening disk image…"))
    )
  }

  #Preview("Install Complete") {
    UpdateAlertView(
      model: .preview(in: .installComplete(appURL: URL(filePath: "/Applications/My App.app")))
    )
  }

  #Preview("Error") {
    UpdateAlertView(
      model: .preview(
        in: .error(
          ErrorInfo(
            description: "A network error occurred.",
            failureReason: "The server could not be reached.",
            recoverySuggestion: "Check your internet connection and try again."
          )
        )
      )
    )
  }
#endif
