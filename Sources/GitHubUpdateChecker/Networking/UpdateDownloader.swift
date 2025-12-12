#if os(macOS)
  import AppKit
#endif
import Foundation
import Logging

/// Progress information for an ongoing download
public struct DownloadProgress: Sendable {
  // MARK: - Properties

  public let bytesWritten: Int64
  public let totalBytes: Int64
  public let fractionCompleted: Double
  public let startTime: Date
  public let currentTime: Date

  /// Estimated time remaining for the download in seconds
  public var estimatedTimeRemaining: TimeInterval? {
    guard bytesWritten > 0, fractionCompleted > 0, fractionCompleted < 1 else {
      return nil
    }

    let elapsedSeconds = currentTime.timeIntervalSince(startTime)
    guard elapsedSeconds > 0 else { return nil }

    let bytesPerSecond = Double(bytesWritten) / elapsedSeconds
    guard bytesPerSecond > 0 else { return nil }

    let remainingBytes = totalBytes - bytesWritten
    return Double(remainingBytes) / bytesPerSecond
  }
}

/// Handles downloading update assets from GitHub
public actor UpdateDownloader {
  // MARK: - Properties

  private var activeDownload:
    (task: URLSessionDownloadTask, continuation: AsyncStream<DownloadProgress>.Continuation)?
  private let session: URLSession
  private let logger = Logger(label: "codes.tim.GitHubUpdateChecker.Downloader")

  // MARK: - Initialization

  /// Creates a new downloader
  public init() {
    let config = URLSessionConfiguration.default
    self.session = URLSession(configuration: config)
  }

  // MARK: - Public Methods

  /// Download an asset to the specified directory
  /// - Parameters:
  ///   - asset: The asset to download
  ///   - directory: The directory to save the file (defaults to ~/Downloads)
  /// - Returns: An async stream of download progress and the final file URL
  public func download(
    asset: GitHubAsset,
    to directory: URL? = nil
  ) async throws -> (progress: AsyncStream<DownloadProgress>, fileURL: URL) {
    // Cancel any existing download
    cancelDownload()

    let targetDirectory =
      directory ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!

    // Ensure the directory exists (important for sandboxed apps)
    if !FileManager.default.fileExists(atPath: targetDirectory.path(percentEncoded: false)) {
      try FileManager.default.createDirectory(
        at: targetDirectory,
        withIntermediateDirectories: true
      )
      logger.debug(
        "Created downloads directory",
        metadata: [
          "path": "\(targetDirectory.path(percentEncoded: false))"
        ]
      )
    }

    let destinationURL = targetDirectory.appendingPathComponent(asset.name)

    // Remove existing file if present
    try? FileManager.default.removeItem(at: destinationURL)

    let (stream, continuation) = AsyncStream<DownloadProgress>.makeStream()

    let downloadTask = Task { [weak self] in
      defer { continuation.finish() }
      try await self?.performDownload(
        from: asset.browserDownloadURL,
        to: destinationURL,
        expectedSize: Int64(asset.size),
        onProgress: { continuation.yield($0) }
      )
    }

    // Wait for download to complete
    try await downloadTask.value

    return (stream, destinationURL)
  }

  /// Download with a progress callback (convenience method)
  /// - Parameters:
  ///   - asset: The asset to download
  ///   - directory: The directory to save the file
  ///   - onProgress: Called with progress updates
  /// - Returns: The URL of the downloaded file
  public func download(
    asset: GitHubAsset,
    to directory: URL? = nil,
    onProgress: @escaping @Sendable (DownloadProgress) -> Void
  ) async throws -> URL {
    let targetDirectory =
      directory ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!

    // Ensure the directory exists (important for sandboxed apps)
    if !FileManager.default.fileExists(atPath: targetDirectory.path(percentEncoded: false)) {
      try FileManager.default.createDirectory(
        at: targetDirectory,
        withIntermediateDirectories: true
      )
      logger.debug(
        "Created downloads directory",
        metadata: [
          "path": "\(targetDirectory.path(percentEncoded: false))"
        ]
      )
    }

    let destinationURL = targetDirectory.appendingPathComponent(asset.name)

    // Remove existing file if present
    try? FileManager.default.removeItem(at: destinationURL)

    try await performDownload(
      from: asset.browserDownloadURL,
      to: destinationURL,
      expectedSize: Int64(asset.size),
      onProgress: onProgress
    )

    return destinationURL
  }

  /// Cancel the current download
  public func cancelDownload() {
    if activeDownload != nil {
      logger.info("Cancelling download")
    }
    activeDownload?.task.cancel()
    activeDownload?.continuation.finish()
    activeDownload = nil
  }

  // MARK: - Private Methods

  private func performDownload(
    from url: URL,
    to destination: URL,
    expectedSize: Int64,
    onProgress: @escaping @Sendable (DownloadProgress) -> Void
  ) async throws {
    logger.info(
      "Starting download",
      metadata: [
        "url": "\(url)",
        "destination": "\(destination.lastPathComponent)",
        "expectedSize": "\(expectedSize)"
      ]
    )

    var request = URLRequest(url: url)
    request.setValue("GitHubUpdateChecker/1.0", forHTTPHeaderField: "User-Agent")

    let asyncBytes: URLSession.AsyncBytes
    let response: URLResponse
    do {
      (asyncBytes, response) = try await session.bytes(for: request)
    } catch {
      logger.error(
        "Failed to start download request",
        metadata: [
          "url": "\(url)",
          "error": "\(error)"
        ]
      )
      throw UpdateCheckError.downloadFailed("Network request failed: \(error.localizedDescription)")
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      logger.error(
        "Invalid response type",
        metadata: [
          "url": "\(url)",
          "responseType": "\(type(of: response))"
        ]
      )
      throw UpdateCheckError.downloadFailed("Invalid response from server")
    }

    logger.debug(
      "Received HTTP response",
      metadata: [
        "statusCode": "\(httpResponse.statusCode)",
        "url": "\(httpResponse.url?.absoluteString ?? "unknown")"
      ]
    )

    guard (200...299).contains(httpResponse.statusCode) else {
      logger.error(
        "Download failed with HTTP error",
        metadata: [
          "statusCode": "\(httpResponse.statusCode)",
          "url": "\(url)"
        ]
      )
      throw UpdateCheckError.downloadFailed("Server returned HTTP \(httpResponse.statusCode)")
    }

    let totalSize =
      httpResponse.expectedContentLength > 0 ? httpResponse.expectedContentLength : expectedSize

    logger.debug(
      "Download response received",
      metadata: [
        "statusCode": "\(httpResponse.statusCode)",
        "contentLength": "\(totalSize)"
      ]
    )

    // Create file handle for writing
    let created = FileManager.default.createFile(
      atPath: destination.path(percentEncoded: false),
      contents: nil
    )
    if !created {
      logger.error(
        "Failed to create destination file",
        metadata: [
          "destination": "\(destination.path(percentEncoded: false))"
        ]
      )
      throw UpdateCheckError.downloadFailed("Could not create destination file")
    }

    let fileHandle: FileHandle
    do {
      fileHandle = try FileHandle(forWritingTo: destination)
    } catch {
      logger.error(
        "Failed to open file handle",
        metadata: [
          "destination": "\(destination.path(percentEncoded: false))",
          "error": "\(error)"
        ]
      )
      throw UpdateCheckError.downloadFailed(
        "Could not open destination file: \(error.localizedDescription)"
      )
    }

    defer {
      try? fileHandle.close()
    }

    var bytesReceived: Int64 = 0
    var buffer = Data()
    let bufferSize = 65536  // 64KB buffer
    let startTime = Date()

    for try await byte in asyncBytes {
      buffer.append(byte)
      bytesReceived += 1

      // Write buffer to file periodically
      if buffer.count >= bufferSize {
        try fileHandle.write(contentsOf: buffer)
        buffer.removeAll(keepingCapacity: true)

        let progress = DownloadProgress(
          bytesWritten: bytesReceived,
          totalBytes: totalSize,
          fractionCompleted: Double(bytesReceived) / Double(totalSize),
          startTime: startTime,
          currentTime: Date()
        )
        onProgress(progress)
      }
    }

    // Write remaining buffer
    if !buffer.isEmpty {
      try fileHandle.write(contentsOf: buffer)
    }

    let elapsedTime = Date().timeIntervalSince(startTime)
    let speedMBps = Double(bytesReceived) / elapsedTime / 1_000_000

    logger.info(
      "Download completed",
      metadata: [
        "fileName": "\(destination.lastPathComponent)",
        "bytesReceived": "\(bytesReceived)",
        "elapsedSeconds": "\(String(format: "%.1f", elapsedTime))",
        "speedMBps": "\(String(format: "%.2f", speedMBps))"
      ]
    )

    // Final progress update
    let finalProgress = DownloadProgress(
      bytesWritten: bytesReceived,
      totalBytes: totalSize,
      fractionCompleted: 1.0,
      startTime: startTime,
      currentTime: Date()
    )
    onProgress(finalProgress)
  }
}

// MARK: - Static Helpers

public extension UpdateDownloader {
  #if os(macOS)
    // MARK: - Type Properties

    /// Whether the app is running in a sandbox
    static var isSandboxed: Bool {
      ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// Check if the app has direct access to the Downloads folder
    static var hasDownloadsFolderEntitlement: Bool {
      guard isSandboxed else { return true }
      return EntitlementChecker.shared.hasDownloadsEntitlement
    }

    /// Check if the app can use NSSavePanel to get write access
    static var hasUserSelectedFileEntitlement: Bool {
      guard isSandboxed else { return true }
      return EntitlementChecker.shared.hasUserSelectedEntitlement
    }

    /// The best available download method for this app
    static var downloadCapability: DownloadCapability {
      if !isSandboxed {
        return .directAccess
      }
      if hasDownloadsFolderEntitlement {
        return .directAccess
      }
      if hasUserSelectedFileEntitlement {
        return .savePanel
      }
      return .browserOnly
    }

    // MARK: - Type Methods

    /// Open the downloaded file using the default application
    /// - Parameter url: The file URL to open
    @MainActor
    static func openDownloadedFile(_ url: URL) {
      NSWorkspace.shared.open(url)
    }

    /// Reveal the downloaded file in Finder
    /// - Parameter url: The file URL to reveal
    @MainActor
    static func revealInFinder(_ url: URL) {
      NSWorkspace.shared.selectFile(
        url.path,
        inFileViewerRootedAtPath: url.deletingLastPathComponent().path
      )
    }

    /// Prompt user to select a save location using NSSavePanel
    /// - Parameters:
    ///   - fileName: The suggested file name
    ///   - directory: The initial directory to show (defaults to Downloads)
    /// - Returns: The selected URL, or nil if cancelled
    @MainActor
    static func promptForSaveLocation(
      fileName: String,
      directory: URL? = nil
    ) async -> URL? {
      let panel = NSSavePanel()
      panel.nameFieldStringValue = fileName
      panel.canCreateDirectories = true
      panel.isExtensionHidden = false

      if let directory {
        panel.directoryURL = directory
      } else {
        // Try to use the real ~/Downloads as the default
        let realDownloads = FileManager.default.homeDirectoryForCurrentUser
          .appendingPathComponent("Downloads")
        if FileManager.default.fileExists(atPath: realDownloads.path(percentEncoded: false)) {
          panel.directoryURL = realDownloads
        }
      }

      let response = await panel.begin()
      return response == .OK ? panel.url : nil
    }

    // MARK: - Nested Types

    /// Describes how the app can handle downloads
    enum DownloadCapability: Sendable {
      /// App can write directly to ~/Downloads
      case directAccess
      /// App needs to use NSSavePanel for user to select location
      case savePanel
      /// App cannot save files, must open URL in browser
      case browserOnly
    }
  #endif
}

#if os(macOS)
  /// Thread-safe entitlement checker
  private final class EntitlementChecker: Sendable {
    static let shared = EntitlementChecker()

    let hasDownloadsEntitlement: Bool
    let hasUserSelectedEntitlement: Bool

    private init() {
      var code: SecCode?
      guard SecCodeCopySelf([], &code) == errSecSuccess, let code else {
        self.hasDownloadsEntitlement = false
        self.hasUserSelectedEntitlement = false
        return
      }

      var staticCode: SecStaticCode?
      guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
        self.hasDownloadsEntitlement = false
        self.hasUserSelectedEntitlement = false
        return
      }

      var info: CFDictionary?
      guard
        SecCodeCopySigningInformation(
          staticCode,
          SecCSFlags(rawValue: kSecCSSigningInformation),
          &info
        )
          == errSecSuccess,
        let info = info as? [String: Any],
        let entitlements = info["entitlements-dict"] as? [String: Any]
      else {
        self.hasDownloadsEntitlement = false
        self.hasUserSelectedEntitlement = false
        return
      }

      self.hasDownloadsEntitlement =
        entitlements["com.apple.security.files.downloads.read-write"] as? Bool ?? false
      self.hasUserSelectedEntitlement =
        entitlements["com.apple.security.files.user-selected.read-write"] as? Bool ?? false
    }
  }
#endif
