#if os(macOS)
  import SwiftUI

  /// The update alert's bottom strip when a download or installation fails: the error's
  /// description, reason, and recovery suggestion beside an OK button.
  struct ErrorAlertView: View {
    let errorInfo: ErrorInfo
    let onDismiss: () -> Void

    var body: some View {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(errorInfo.description)

          Group {
            if let failureReason = errorInfo.failureReason {
              Text(failureReason)
            }
            if let recoverySuggestion = errorInfo.recoverySuggestion {
              Text(recoverySuggestion)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)

        Spacer()

        Button("OK") {
          onDismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
  }

  // MARK: - Preview

  #Preview("With Recovery Suggestion") {
    ErrorAlertView(
      errorInfo: ErrorInfo(
        description: "A network error occurred.",
        failureReason: "The server could not be reached.",
        recoverySuggestion: "Check your internet connection and try again."
      ),
      onDismiss: {}
    )
    .padding()
    .frame(width: 500)
  }

  #Preview("Without Recovery Suggestion") {
    ErrorAlertView(
      errorInfo: ErrorInfo(
        description: "The operation was cancelled.",
        failureReason: "The download was cancelled by the user.",
        recoverySuggestion: nil
      ),
      onDismiss: {}
    )
    .padding()
    .frame(width: 500)
  }

  #Preview("Minimal") {
    ErrorAlertView(
      errorInfo: ErrorInfo(
        description: "An error occurred.",
        failureReason: nil,
        recoverySuggestion: nil
      ),
      onDismiss: {}
    )
    .padding()
    .frame(width: 500)
  }
#endif
