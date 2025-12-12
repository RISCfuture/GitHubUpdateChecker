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

  /// Shows installation progress after download completes
  struct InstallProgressView: View {
    var model: InstallProgressModel

    var body: some View {
      VStack {
        // Progress indicator
        ProgressView()
          .controlSize(.large)
          .padding(.bottom)

        // Phase title
        Text("Installing Update")
          .font(.headline)

        // Status message
        Text(model.statusMessage)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        // Cancel button (only show during certain phases)
        if canCancel {
          Button("Cancel") {
            model.onCancel()
          }
          .keyboardShortcut(.cancelAction)
          .buttonStyle(.borderless)
          .padding(.top, 8)
        }
      }
      .padding()
      .frame(minWidth: 350)
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
  }

  #Preview("Mounting") {
    let model = InstallProgressModel()
    model.update(phase: .mounting, message: "Opening disk image...", onCancel: {})
    return InstallProgressView(model: model)
  }
#endif
