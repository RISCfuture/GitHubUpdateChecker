#if os(macOS)
  public import AppKit
  public import Foundation
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

      let destinationPath = destination.path.shellQuoted
      try runWithAdministratorPrivileges(
        "rm -rf \(destinationPath) && cp -R \(source.path.shellQuoted) \(destinationPath)"
      )

      logger.info("Elevated copy completed successfully")
    }

    /**
     Install a package with `installer(8)`.

     Unlike a copy, this always needs the password: `installer` writes as root whatever the
     package's own permissions on the destination happen to be, and refuses to run otherwise.

     The target is the boot volume rather than a directory. `installer` takes a volume and leaves
     the destination within it to the package, so where the bundle lands is the package's decision
     and not this call's — which is why the caller verifies the result rather than assuming it.

     - Parameter packageURL: The package file to install
     - Throws: `AuthorizationError` if the install fails or the password dialog is dismissed
     */
    @MainActor
    public static func installPackage(at packageURL: URL) throws {
      logger.info(
        "Requesting elevated privileges for package install",
        metadata: ["package": "\(packageURL.path)"]
      )

      try runWithAdministratorPrivileges("installer -pkg \(packageURL.path.shellQuoted) -target /")

      logger.info("Package install completed successfully")
    }

    /// Runs a shell command as an administrator, prompting for a password through the standard
    /// macOS dialog. AppleScript requires the main thread.
    @MainActor
    private static func runWithAdministratorPrivileges(_ command: String) throws {
      let script = """
        do shell script "\(command.escapedForAppleScriptLiteral)" with administrator privileges
        """

      // swiftlint:disable:next legacy_objc_type
      var error: NSDictionary?
      guard let appleScript = NSAppleScript(source: script) else {
        throw AuthorizationError.failed("Failed to create AppleScript")
      }

      _ = appleScript.executeAndReturnError(&error)

      guard let error else { return }

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

  // MARK: - Quoting

  extension String {
    /// The string as one shell word, safe to interpolate into a command.
    ///
    /// Single quotes protect everything a path may contain except a single quote itself, which
    /// closes the quoting and is spliced back in escaped.
    var shellQuoted: String {
      "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    /// The string escaped for embedding in an AppleScript double-quoted literal.
    ///
    /// Backslashes are escaped first, so that the pass over the double quotes cannot escape the
    /// backslashes this step introduces.
    var escapedForAppleScriptLiteral: String {
      replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    }
  }
#endif
