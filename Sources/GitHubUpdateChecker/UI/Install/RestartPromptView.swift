#if os(macOS)
  import SwiftUI

  /// The update alert's bottom strip after a successful installation: a restart prompt with Later
  /// and Restart Now buttons.
  struct RestartPromptView: View {
    let appName: String
    let newVersion: String
    let onRestartNow: () -> Void
    let onRestartLater: () -> Void

    var body: some View {
      HStack {
        UpdateStatusText(title: Text("Update Installed")) {
          Text("\(appName) \(newVersion) has been installed. Restart to use the new version.")
        }

        Spacer()

        Button("Later") { onRestartLater() }
          .keyboardShortcut(.cancelAction)

        Button("Restart Now") { onRestartNow() }
          .keyboardShortcut(.defaultAction)
      }
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
    .padding()
    .frame(width: 500)
  }
#endif
