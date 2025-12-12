#if os(macOS)
  import AppKit
  import SwiftUI

  /// The main update alert dialog view
  struct UpdateAlertView: View {
    var model: UpdateAlertModel

    var body: some View {
      VStack {
        if let release = model.release {
          UpdateAlertHeader(
            appIcon: model.appIcon,
            appName: model.appName,
            newVersion: release.version ?? SemanticVersion(major: 0),
            currentVersion: model.currentVersion
          )

          ReleaseNotesView(release: release)

          UpdateAlertButtons(
            onSkip: model.onSkip,
            onRemindLater: model.onRemindLater,
            onDownload: model.onDownload
          )
          .disabled(model.state != .idle)
        }
      }
      .padding(20)
      .frame(minWidth: 300, minHeight: 400)
    }
  }

  // MARK: - Header

  struct UpdateAlertHeader: View {
    let appIcon: NSImage
    let appName: String
    let newVersion: SemanticVersion
    let currentVersion: SemanticVersion

    var body: some View {
      HStack(alignment: .center) {
        Image(nsImage: appIcon)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 64, height: 64)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text("A new version of \(appName) is available.")
            .font(.headline)

          Text(
            "\(appName) \(newVersion.description) is now available. You have version \(currentVersion.description)."
          )
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }

        Spacer()
      }
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

  // MARK: - Preview

  #Preview {
    let model = UpdateAlertModel()
    model.configure(
      release: GitHubRelease(
        id: 1,
        tagName: "v2.0.0",
        name: "Version 2.0.0",
        body: """
          ## What's New

          - **New Feature**: Added dark mode support
          - **Improvement**: Better performance
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
    return UpdateAlertView(model: model)
  }
#endif
