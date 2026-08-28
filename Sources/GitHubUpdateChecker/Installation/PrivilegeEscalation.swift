#if os(macOS)
  import AppKit
  import Foundation
  import Logging
  import Security

  /// Handles privilege escalation for protected locations
  public enum PrivilegeEscalation {
    private static let logger = Logger(label: "codes.tim.GitHubUpdateChecker.PrivilegeEscalation")

    /**
     Check if a location requires elevated privileges to write to.

     Installing over an app replaces whatever is already at the destination, which needs write
     access both to the enclosing directory, to swap the entry itself, and to the item being
     replaced, to delete the tree underneath it. An app placed by a `.pkg` installer is the case
     that makes the second check matter: the installer leaves the bundle owned by `root:wheel` and
     mode `755` inside an `/Applications` that stays group-writable by `admin`, so the enclosing
     directory alone reports the location as writable while unlinking anything inside the bundle
     fails.

     The existing item is probed at its root rather than at a path within it, such as `Contents`,
     because `isWritableFile(atPath:)` on a directory reports whether entries can be created and
     removed inside it: a recursive delete cannot reach `Contents` at all without permission to
     write to the bundle root that holds it.

     - Parameter url: The destination URL to check
     - Returns: true if the current user cannot replace the item at the location
     */
    public static func requiresElevation(for url: URL) -> Bool {
      !canSwapEntry(at: url) || !canDeleteExistingItem(at: url)
    }

    private static func canSwapEntry(at url: URL) -> Bool {
      FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path)
    }

    private static func canDeleteExistingItem(at url: URL) -> Bool {
      let fileManager = FileManager.default
      guard fileManager.fileExists(atPath: url.path) else { return true }
      return fileManager.isWritableFile(atPath: url.path)
    }

    /// Copy a file using elevated privileges via AppleScript
    /// - Parameters:
    ///   - source: The source file URL
    ///   - destination: The destination file URL
    /// - Throws: `AuthorizationError` if the copy fails
    @MainActor
    public static func copyWithElevatedPrivileges(from source: URL, to destination: URL)
      throws
    {
      logger.info(
        "Requesting elevated privileges for copy",
        metadata: [
          "source": "\(source.path)",
          "destination": "\(destination.path)"
        ]
      )

      // Use AppleScript to run with administrator privileges
      // This will prompt for password via the standard macOS dialog
      let script = """
        do shell script "rm -rf '\(destination.path.escapedForShell)' && cp -R \
        '\(source.path.escapedForShell)' '\(destination.path.escapedForShell)'" with administrator \
        privileges
        """

      // swiftlint:disable:next legacy_objc_type
      var error: NSDictionary?
      guard let appleScript = NSAppleScript(source: script) else {
        throw AuthorizationError.failed("Failed to create AppleScript")
      }

      // Run on main thread (required for AppleScript)
      _ = appleScript.executeAndReturnError(&error)

      if let error {
        let errorMessage =
          error[NSAppleScript.errorMessage] as? String ?? "Unknown authorization error"
        let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? 0

        logger.error(
          "AppleScript failed",
          metadata: [
            "error": "\(errorMessage)",
            "errorNumber": "\(errorNumber)"
          ]
        )

        // Error -128 is user cancelled
        if errorNumber == -128 {
          throw AuthorizationError.denied
        }

        throw AuthorizationError.failed(errorMessage)
      }

      logger.info("Elevated copy completed successfully")
    }

    /// Request authorization using the Security framework
    /// This is an alternative to AppleScript that provides more control
    /// - Returns: An authorization reference
    /// - Throws: `AuthorizationError` if authorization fails
    public static func requestAuthorization() throws -> AuthorizationRef {
      var authRef: AuthorizationRef?

      // Create authorization with pre-authorization for privileged operations
      let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]

      let status = AuthorizationCreate(nil, nil, flags, &authRef)

      guard status == errAuthorizationSuccess, let ref = authRef else {
        if status == errAuthorizationCanceled {
          throw AuthorizationError.denied
        }
        throw AuthorizationError.failed(
          "Authorization failed with status: \(status)"
        )
      }

      return ref
    }

    /// Free an authorization reference
    /// - Parameter authRef: The authorization reference to free
    public static func freeAuthorization(_ authRef: AuthorizationRef) {
      AuthorizationFree(authRef, [])
    }
  }

  // MARK: - String Extension for Shell Escaping

  extension String {
    /// Escape a string for use in a shell command
    var escapedForShell: String {
      // Replace single quotes with escaped version
      self.replacingOccurrences(of: "'", with: "'\\''")
    }
  }
#endif
