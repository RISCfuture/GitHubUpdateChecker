#if os(macOS)
  import AppKit
  import SwiftUI

  /// Observable model for download progress
  @Observable
  @MainActor
  final class DownloadProgressModel {
    var fileName: String = ""
    var progress: Double = 0
    var downloadedBytes: Measurement<UnitInformationStorage>?
    var totalBytes: Measurement<UnitInformationStorage>?
    var timeRemaining: TimeInterval?
    var onCancel: () -> Void = {}

    func update(
      fileName: String,
      progress: Double,
      downloadedBytes: Measurement<UnitInformationStorage>?,
      totalBytes: Measurement<UnitInformationStorage>?,
      timeRemaining: TimeInterval?,
      onCancel: @escaping () -> Void
    ) {
      self.fileName = fileName
      self.progress = progress
      self.downloadedBytes = downloadedBytes
      self.totalBytes = totalBytes
      self.timeRemaining = timeRemaining
      self.onCancel = onCancel
    }
  }

  /// A view showing download progress for an update
  struct DownloadProgressView: View {
    // MARK: - Type Properties

    private static let timeRemainingFormatter: DateComponentsFormatter = {
      let formatter = DateComponentsFormatter()
      formatter.unitsStyle = .full
      formatter.includesTimeRemainingPhrase = true
      formatter.allowedUnits = [.hour, .minute, .second]
      return formatter
    }()

    // MARK: - Instance Properties

    var model: DownloadProgressModel

    // MARK: - Body

    var body: some View {
      VStack(alignment: .leading) {
        Text("Downloading update…")
          .font(.headline)

        VStack(alignment: .leading, spacing: 4) {
          ProgressView(value: model.progress, total: 1.0)
            .progressViewStyle(.linear)

          HStack {
            if let downloadedBytes = model.downloadedBytes, let totalBytes = model.totalBytes {
              Text(
                "\(downloadedBytes, format: .byteCount(style: .file)) of \(totalBytes, format: .byteCount(style: .file))"
              )
            }
            Spacer()
            if let timeRemaining = model.timeRemaining,
              let formatted = Self.timeRemainingFormatter.string(from: timeRemaining)
            {
              Text(formatted)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .padding(.bottom)

        HStack {
          Spacer()
          Button("Cancel") {
            model.onCancel()
          }
          Spacer()
        }
      }
      .padding()
      .frame(width: 350)
    }
  }

  // MARK: - Preview

  #Preview {
    let model = DownloadProgressModel()
    model.update(
      fileName: "MyApp-2.0.0.dmg",
      progress: 0.45,
      downloadedBytes: Measurement(value: 12.5, unit: .megabytes),
      totalBytes: Measurement(value: 28.0, unit: .megabytes),
      timeRemaining: 154,
      onCancel: {}
    )
    return DownloadProgressView(model: model)
  }
#endif
