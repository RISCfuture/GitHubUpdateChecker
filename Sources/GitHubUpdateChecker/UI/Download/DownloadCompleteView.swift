#if os(macOS)
  import SwiftUI

  /// A view shown when download completes
  struct DownloadCompleteView: View {
    let fileName: String
    let fileURL: URL
    let canInstall: Bool
    let onRevealInFinder: () -> Void
    let onInstall: () -> Void
    let onClose: () -> Void

    var body: some View {
      VStack(alignment: .leading, spacing: 24) {
        // Header: icon + text
        HStack {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 36))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

          VStack(alignment: .leading) {
            Text("Download Complete")
              .font(.headline)

            Text(fileName)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
          }
        }

        // Action buttons
        HStack {
          Button("Close") { onClose() }
            .keyboardShortcut(.cancelAction)

          Spacer()

          Button("Show in Finder") { onRevealInFinder() }

          if canInstall {
            Button("Install Update") { onInstall() }
              .keyboardShortcut(.defaultAction)
          }
        }
      }
      .padding()
      .frame(minWidth: 200)
    }
  }

  // MARK: - Previews

  #Preview("Auto Install (DMG)") {
    DownloadCompleteView(
      fileName: "MyApp-2.0.0.dmg",
      fileURL: URL(fileURLWithPath: "/Users/test/Downloads/MyApp-2.0.0.dmg"),
      canInstall: true,
      onRevealInFinder: {},
      onInstall: {},
      onClose: {}
    )
  }

  #Preview("Manual Install (PKG)") {
    DownloadCompleteView(
      fileName: "MyApp-2.0.0.pkg",
      fileURL: URL(fileURLWithPath: "/Users/test/Downloads/MyApp-2.0.0.pkg"),
      canInstall: false,
      onRevealInFinder: {},
      onInstall: {},
      onClose: {}
    )
  }
#endif
