#if os(macOS)
  import SwiftUI

  /// Prompts user to restart now or later after successful installation
  struct RestartPromptView: View {
    let appName: String
    let newVersion: String
    let onRestartNow: () -> Void
    let onRestartLater: () -> Void

    var body: some View {
      VStack(alignment: .leading, spacing: 24) {
        // Header: icon + text
        HStack {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 36))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 4) {
            Text("Update Installed")
              .font(.headline)

            Text("\(appName) \(newVersion) has been installed. Restart to use the new version.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }

        // Buttons
        HStack {
          Spacer()

          Button("Later") { onRestartLater() }
            .keyboardShortcut(.cancelAction)

          Button("Restart Now") { onRestartNow() }
            .keyboardShortcut(.defaultAction)
        }
      }
      .padding()
      .frame(minWidth: 200)
    }
  }

  // MARK: - Preview

  #Preview {
    RestartPromptView(
      appName: "MyApp",
      newVersion: "2.0.0",
      onRestartNow: {},
      onRestartLater: {}
    )
  }
#endif
