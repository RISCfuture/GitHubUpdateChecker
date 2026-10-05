#if os(macOS)
  import SwiftUI

  /// A title with caption-sized detail beneath it, for the status side of the update alert's
  /// bottom strip.
  struct UpdateStatusText<Detail: View>: View {
    let title: Text
    @ViewBuilder let detail: Detail

    var body: some View {
      VStack(alignment: .leading, spacing: 2) {
        title
        detail
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Preview

  #Preview {
    UpdateStatusText(title: Text("Download Complete")) {
      Text("MyApp-2.0.0.dmg")
    }
    .padding()
  }
#endif
