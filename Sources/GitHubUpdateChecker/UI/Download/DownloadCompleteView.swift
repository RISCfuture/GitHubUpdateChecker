#if os(macOS)
  import SwiftUI

  /// The update alert's bottom strip once the download has finished: buttons to close the alert,
  /// reveal the downloaded file, or install it.
  struct DownloadCompleteView: View {
    let canInstall: Bool
    let onRevealInFinder: () -> Void
    let onInstall: () -> Void
    let onClose: () -> Void

    var body: some View {
      HStack {
        Spacer()

        Button("Close") { onClose() }
          .keyboardShortcut(.cancelAction)

        Button("Show in Finder") { onRevealInFinder() }

        if canInstall {
          Button("Install Update") { onInstall() }
            .keyboardShortcut(.defaultAction)
        }
      }
    }
  }

  // MARK: - Previews

  #Preview("Auto Install (DMG)") {
    DownloadCompleteView(
      canInstall: true,
      onRevealInFinder: {},
      onInstall: {},
      onClose: {}
    )
    .padding()
    .frame(width: 500)
  }

  #Preview("Manual Install (PKG)") {
    DownloadCompleteView(
      canInstall: false,
      onRevealInFinder: {},
      onInstall: {},
      onClose: {}
    )
    .padding()
    .frame(width: 500)
  }
#endif
