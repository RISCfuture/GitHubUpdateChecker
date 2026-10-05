#if os(macOS)
  import SwiftUI

  /// The update alert's bottom strip after a successful installation: Later and Restart Now
  /// buttons.
  struct RestartPromptView: View {
    let onRestartNow: () -> Void
    let onRestartLater: () -> Void

    var body: some View {
      HStack {
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
    RestartPromptView(onRestartNow: {}, onRestartLater: {})
      .padding()
      .frame(width: 500)
  }
#endif
