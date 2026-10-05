#if os(macOS)
  import SwiftUI

  /// Observable model for installation progress
  @Observable
  @MainActor
  final class InstallProgressModel {
    var phase: InstallPhase = .preparing
    var statusMessage = String(localized: "Preparing…")
    var onCancel: () -> Void = {}

    func update(phase: InstallPhase, message: String, onCancel: @escaping () -> Void) {
      self.phase = phase
      self.statusMessage = message
      self.onCancel = onCancel
    }
  }

  /// The update alert's bottom strip while an update installs: a spinner beside the current phase's
  /// message, and a Cancel button for the phases that can still be abandoned.
  struct InstallProgressView: View {
    var model: InstallProgressModel

    var body: some View {
      HStack(spacing: 12) {
        ProgressView()
          .controlSize(.small)

        Text(model.statusMessage)

        Spacer()

        if canCancel {
          Button("Cancel") {
            model.onCancel()
          }
          .keyboardShortcut(.cancelAction)
        }
      }
    }

    private var canCancel: Bool {
      switch model.phase {
        case .preparing, .mounting, .extracting:
          return true
        case .copying, .verifying, .unmounting, .cleaning, .complete:
          return false
      }
    }
  }

  // MARK: - Preview

  #Preview("Installing") {
    let model = InstallProgressModel()
    model.update(phase: .copying, message: "Installing update...", onCancel: {})
    return InstallProgressView(model: model)
      .padding()
      .frame(width: 500)
  }

  #Preview("Mounting") {
    let model = InstallProgressModel()
    model.update(phase: .mounting, message: "Opening disk image...", onCancel: {})
    return InstallProgressView(model: model)
      .padding()
      .frame(width: 500)
  }
#endif
