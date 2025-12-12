#if os(macOS)
  import Foundation
  import Logging

  /// Handles mounting, extracting apps from, and unmounting DMG files
  public actor DMGHandler {
    private let logger = Logger(label: "codes.tim.GitHubUpdateChecker.DMGHandler")

    /// Creates a new DMG handler
    public init() {}

    /// Mount a DMG and return the mount point
    /// - Parameter dmgURL: The URL of the DMG file to mount
    /// - Returns: The URL of the mount point
    /// - Throws: `DiskImageError.mountFailed` if mounting fails
    public func mount(dmgURL: URL) throws -> URL {
      logger.info("Mounting DMG", metadata: ["path": "\(dmgURL.path)"])

      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
      process.arguments = [
        "attach",
        dmgURL.path,
        "-nobrowse",  // Don't open in Finder
        "-noverify",  // Skip verification for speed
        "-plist"  // Output as plist for parsing
      ]

      let outputPipe = Pipe()
      let errorPipe = Pipe()
      process.standardOutput = outputPipe
      process.standardError = errorPipe

      do {
        try process.run()
      } catch {
        throw DiskImageError.mountFailed("Failed to run hdiutil: \(error.localizedDescription)")
      }

      process.waitUntilExit()

      guard process.terminationStatus == 0 else {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        logger.error(
          "hdiutil attach failed",
          metadata: [
            "status": "\(process.terminationStatus)",
            "error": "\(errorMessage)"
          ]
        )
        throw DiskImageError.mountFailed("hdiutil failed: \(errorMessage)")
      }

      // Parse plist output to get mount point
      let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

      guard
        let plist =
          try? PropertyListSerialization.propertyList(from: outputData, format: nil)
          as? [String: Any],
        let systemEntities = plist["system-entities"] as? [[String: Any]]
      else {
        throw DiskImageError.mountFailed("Failed to parse hdiutil output")
      }

      // Find the mount point from system entities
      for entity in systemEntities {
        if let mountPoint = entity["mount-point"] as? String {
          let mountURL = URL(fileURLWithPath: mountPoint)
          logger.info("DMG mounted successfully", metadata: ["mountPoint": "\(mountPoint)"])
          return mountURL
        }
      }

      throw DiskImageError.mountFailed("No mount point found in hdiutil output")
    }

    /// Find the .app bundle inside a mounted DMG
    /// - Parameter mountPoint: The URL of the DMG mount point
    /// - Returns: The URL of the .app bundle
    /// - Throws: `DiskImageError.appNotFound` if no app is found
    public func findApp(in mountPoint: URL) throws -> URL {
      logger.debug("Searching for app in mount point", metadata: ["path": "\(mountPoint.path)"])

      let fileManager = FileManager.default

      guard
        let contents = try? fileManager.contentsOfDirectory(
          at: mountPoint,
          includingPropertiesForKeys: [.isDirectoryKey],
          options: [.skipsHiddenFiles]
        )
      else {
        throw DiskImageError.appNotFound
      }

      // Look for .app bundles
      let apps = contents.filter { $0.pathExtension == "app" }

      if let appURL = apps.first {
        logger.info("Found app in DMG", metadata: ["app": "\(appURL.lastPathComponent)"])
        return appURL
      }

      // Some DMGs have a nested Applications folder or similar
      for item in contents {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
          isDirectory.boolValue
        {
          if let nestedContents = try? fileManager.contentsOfDirectory(
            at: item,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
          ) {
            if let nestedApp = nestedContents.first(where: { $0.pathExtension == "app" }) {
              logger.info(
                "Found app in nested folder",
                metadata: [
                  "app": "\(nestedApp.lastPathComponent)"
                ]
              )
              return nestedApp
            }
          }
        }
      }

      logger.error("No app found in DMG", metadata: ["mountPoint": "\(mountPoint.path)"])
      throw DiskImageError.appNotFound
    }

    /// Unmount a DMG
    /// - Parameter mountPoint: The URL of the mount point to unmount
    /// - Throws: `DiskImageError.unmountFailed` if unmounting fails (usually non-fatal)
    public func unmount(mountPoint: URL) throws {
      logger.info("Unmounting DMG", metadata: ["mountPoint": "\(mountPoint.path)"])

      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
      process.arguments = ["detach", mountPoint.path, "-force"]

      let errorPipe = Pipe()
      process.standardError = errorPipe

      do {
        try process.run()
      } catch {
        logger.warning(
          "Failed to run hdiutil detach",
          metadata: [
            "error": "\(error.localizedDescription)"
          ]
        )
        throw DiskImageError.unmountFailed(error.localizedDescription)
      }

      process.waitUntilExit()

      if process.terminationStatus != 0 {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
        logger.warning(
          "hdiutil detach failed",
          metadata: [
            "status": "\(process.terminationStatus)",
            "error": "\(errorMessage)"
          ]
        )
        throw DiskImageError.unmountFailed(errorMessage)
      }

      logger.info("DMG unmounted successfully")
    }
  }
#endif
