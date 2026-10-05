#if os(macOS)
  import SwiftUI

  /// The update alert's bottom strip once the download has finished: the downloaded file's name
  /// beside buttons to reveal it, install it, or close the alert.
  struct DownloadCompleteView: View {
    let fileName: String
    let canInstall: Bool
    let onRevealInFinder: () -> Void
    let onInstall: () -> Void
    let onClose: () -> Void

    var body: some View {
      HStack {
        UpdateStatusText(title: Text("Download Complete")) {
          Text(fileName)
            .lineLimit(1)
            .truncationMode(.middle)
        }

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
      fileName: "MyApp-2.0.0.dmg",
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
      fileName: "MyApp-2.0.0.pkg",
      canInstall: false,
      onRevealInFinder: {},
      onInstall: {},
      onClose: {}
    )
    .padding()
    .frame(width: 500)
  }
#endif
