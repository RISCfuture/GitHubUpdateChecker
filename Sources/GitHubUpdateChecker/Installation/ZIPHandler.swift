#if os(macOS)
  import Foundation
  import Logging

  /// Handles extracting .app bundles from ZIP files
  public actor ZIPHandler {
    private let logger = Logger(label: "codes.tim.GitHubUpdateChecker.ZIPHandler")

    /// Creates a new ZIP handler
    public init() {}

    /// Extract a ZIP file to a temporary directory and return the extracted .app URL
    /// - Parameters:
    ///   - zipURL: The URL of the ZIP file to extract
    ///   - directory: The directory to extract to (defaults to a temp directory)
    /// - Returns: The URL of the extracted .app bundle
    /// - Throws: `ArchiveError.extractionFailed` or `ArchiveError.appNotFound`
    public func extract(zipURL: URL, to directory: URL? = nil) throws -> URL {
      logger.info("Extracting ZIP", metadata: ["path": "\(zipURL.path)"])

      // Create extraction directory
      let extractionDir: URL
      if let directory {
        extractionDir = directory
      } else {
        extractionDir =
          FileManager.default.temporaryDirectory
          .appendingPathComponent("GitHubUpdateChecker-\(UUID().uuidString)")
      }

      do {
        try FileManager.default.createDirectory(
          at: extractionDir,
          withIntermediateDirectories: true
        )
      } catch {
        throw ArchiveError.extractionFailed(
          "Failed to create extraction directory: \(error.localizedDescription)"
        )
      }

      logger.debug("Extraction directory created", metadata: ["path": "\(extractionDir.path)"])

      // Use ditto for extraction (handles resource forks properly on macOS)
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
      process.arguments = ["-xk", zipURL.path, extractionDir.path]

      let errorPipe = Pipe()
      process.standardError = errorPipe

      do {
        try process.run()
      } catch {
        // Clean up on failure
        try? FileManager.default.removeItem(at: extractionDir)
        throw ArchiveError.extractionFailed(
          "Failed to run ditto: \(error.localizedDescription)"
        )
      }

      process.waitUntilExit()

      guard process.terminationStatus == 0 else {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        logger.error(
          "ditto extraction failed",
          metadata: [
            "status": "\(process.terminationStatus)",
            "error": "\(errorMessage)"
          ]
        )
        // Clean up on failure
        try? FileManager.default.removeItem(at: extractionDir)
        throw ArchiveError.extractionFailed("ditto failed: \(errorMessage)")
      }

      logger.info("ZIP extracted successfully")

      // Find the .app bundle in the extracted contents
      return try findApp(in: extractionDir)
    }

    /// Find the .app bundle in an extracted directory
    /// - Parameter directory: The directory to search
    /// - Returns: The URL of the .app bundle
    /// - Throws: `ArchiveError.appNotFound` if no app is found
    public func findApp(in directory: URL) throws -> URL {
      logger.debug("Searching for app in directory", metadata: ["path": "\(directory.path)"])

      let fileManager = FileManager.default

      // First, check top-level contents
      if let contents = try? fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      ) {
        // Check for .app at top level
        if let appURL = contents.first(where: { $0.pathExtension == "app" }) {
          logger.info("Found app in ZIP", metadata: ["app": "\(appURL.lastPathComponent)"])
          return appURL
        }
      }

      // Search recursively (some ZIPs nest the .app in folders)
      guard
        let enumerator = fileManager.enumerator(
          at: directory,
          includingPropertiesForKeys: [.isDirectoryKey],
          options: [.skipsHiddenFiles]
        )
      else {
        throw ArchiveError.appNotFound
      }

      while let url = enumerator.nextObject() as? URL {
        if url.pathExtension == "app" {
          // Verify it's actually a bundle (has Contents folder)
          let contentsURL = url.appendingPathComponent("Contents")
          var isDirectory: ObjCBool = false
          if fileManager.fileExists(atPath: contentsURL.path, isDirectory: &isDirectory),
            isDirectory.boolValue
          {
            logger.info("Found app in ZIP (nested)", metadata: ["app": "\(url.lastPathComponent)"])
            return url
          }
        }
      }

      logger.error("No app found in ZIP", metadata: ["directory": "\(directory.path)"])
      throw ArchiveError.appNotFound
    }

    /// Clean up an extraction directory
    /// - Parameter directory: The directory to remove
    public func cleanup(directory: URL) {
      logger.debug("Cleaning up extraction directory", metadata: ["path": "\(directory.path)"])
      try? FileManager.default.removeItem(at: directory)
    }
  }
#endif
