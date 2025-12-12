#if os(macOS)
  import SwiftUI

  /// A view displaying structured error information
  struct ErrorAlertView: View {
    let errorInfo: ErrorInfo
    let onDismiss: () -> Void

    var body: some View {
      VStack(spacing: 4) {
        // Error icon
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 48))
          .foregroundStyle(.red)
          .accessibilityHidden(true)

        // Error category (errorDescription)
        Text(errorInfo.description)
          .font(.headline)
          .multilineTextAlignment(.center)

        // Failure reason (instance-specific details)
        if let failureReason = errorInfo.failureReason {
          Text(failureReason)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        // Recovery suggestion (actionable instructions)
        if let recoverySuggestion = errorInfo.recoverySuggestion {
          Text(recoverySuggestion)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
        }

        Button("OK") {
          onDismiss()
        }
        .keyboardShortcut(.defaultAction)
        .padding(.top, 8)
      }
      .padding()
      .frame(minWidth: 300)
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
  }
#endif
