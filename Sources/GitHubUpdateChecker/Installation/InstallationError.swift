#if os(macOS)
  import Foundation

  // MARK: - Base Protocol

  /// Base protocol for all installation errors
  public protocol InstallationError: LocalizedError, Sendable {}

  // MARK: - Disk Image Errors

  /// Errors related to disk image (DMG) operations
  public enum DiskImageError: InstallationError {
    /// Failed to mount the DMG file
    case mountFailed(String)

    /// No application bundle was found in the DMG
    case appNotFound

    /// Failed to unmount the DMG (non-fatal)
    case unmountFailed(String)

    public var errorDescription: String? {
      String(localized: "A disk image error occurred.", bundle: .module)
    }

    public var failureReason: String? {
      switch self {
        case .mountFailed(let detail):
          return String(
            localized: "Failed to mount the disk image: \(detail)",
            bundle: .module
          )
        case .appNotFound:
          return String(
            localized: "No application bundle was found inside the disk image.",
            bundle: .module
          )
        case .unmountFailed(let detail):
          return String(
            localized: "Failed to unmount the disk image: \(detail)",
            bundle: .module
          )
      }
    }

    public var recoverySuggestion: String? {
      switch self {
        case .mountFailed, .appNotFound:
          return String(
            localized: "The downloaded file may be corrupted. Try downloading the update again.",
            bundle: .module
          )
        case .unmountFailed:
          return nil
      }
    }
  }

  // MARK: - Archive Errors

  /// Errors related to archive (ZIP) operations
  public enum ArchiveError: InstallationError {
    /// Failed to extract the archive
    case extractionFailed(String)

    /// No application bundle was found in the archive
    case appNotFound

    public var errorDescription: String? {
      String(localized: "An archive error occurred.", bundle: .module)
    }

    public var failureReason: String? {
      switch self {
        case .extractionFailed(let detail):
          return String(
            localized: "Failed to extract the archive: \(detail)",
            bundle: .module
          )
        case .appNotFound:
          return String(
            localized: "No application bundle was found inside the archive.",
            bundle: .module
          )
      }
    }

    public var recoverySuggestion: String? {
      String(
        localized: "The downloaded file may be corrupted. Try downloading the update again.",
        bundle: .module
      )
    }
  }

  // MARK: - File Operation Errors

  /// Errors related to file copy operations
  public enum FileCopyError: InstallationError {
    /// Failed to copy the application
    case copyFailed(String)

    /// Failed to clean up temporary files (non-fatal)
    case cleanupFailed(String)

    public var errorDescription: String? {
      String(localized: "A file operation error occurred.", bundle: .module)
    }

    public var failureReason: String? {
      switch self {
        case .copyFailed(let detail):
          return String(
            localized: "Failed to copy the application: \(detail)",
            bundle: .module
          )
        case .cleanupFailed(let detail):
          return String(
            localized: "Failed to remove temporary files: \(detail)",
            bundle: .module
          )
      }
    }

    public var recoverySuggestion: String? {
      switch self {
        case .copyFailed:
          return String(
            localized: "Check that you have enough disk space and try again.",
            bundle: .module
          )
        case .cleanupFailed:
          return nil
      }
    }
  }

  // MARK: - Authorization Errors

  /// Errors related to authorization and permissions
  public enum AuthorizationError: InstallationError {
    /// The user denied the authorization request
    case denied

    /// Authorization failed for another reason
    case failed(String)

    /// The app is sandboxed and cannot perform automatic installations
    case sandboxRestriction

    public var errorDescription: String? {
      String(localized: "An authorization error occurred.", bundle: .module)
    }

    public var failureReason: String? {
      switch self {
        case .denied:
          return String(
            localized: "Administrator permission was denied.",
            bundle: .module
          )
        case .failed(let detail):
          return String(
            localized: "Authorization failed: \(detail)",
            bundle: .module
          )
        case .sandboxRestriction:
          return String(
            localized:
              "This application is sandboxed and cannot write to the installation location.",
            bundle: .module
          )
      }
    }

    public var recoverySuggestion: String? {
      switch self {
        case .denied:
          return String(
            localized:
              "Click \"Install Update\" again and enter your administrator password when prompted.",
            bundle: .module
          )
        case .failed:
          return String(
            localized: "Try again. If the problem persists, install the update manually.",
            bundle: .module
          )
        case .sandboxRestriction:
          return String(
            localized: "Open the downloaded file to install manually.",
            bundle: .module
          )
      }
    }
  }

  // MARK: - Verification Errors

  /// Errors related to verifying the installed application
  public enum VerificationError: InstallationError {
    /// The installed application failed verification
    case failed(String)

    public var errorDescription: String? {
      String(localized: "A verification error occurred.", bundle: .module)
    }

    public var failureReason: String? {
      switch self {
        case .failed(let detail):
          return String(
            localized: "The installed application failed verification: \(detail)",
            bundle: .module
          )
      }
    }

    public var recoverySuggestion: String? {
      String(
        localized:
          "Try downloading the update again. If the problem persists, contact the developer.",
        bundle: .module
      )
    }
  }

  // MARK: - General Installation Errors

  /// General installation errors that don't fit other categories
  public enum GeneralInstallationError: InstallationError {
    /// The file type is not supported for automatic installation
    case unsupportedFileType(String)

    /// The application is currently in use and cannot be replaced
    case appInUse

    /// The installation was cancelled by the user
    case cancelled

    public var errorDescription: String? {
      switch self {
        case .unsupportedFileType:
          return String(localized: "An unsupported file type error occurred.", bundle: .module)
        case .appInUse:
          return String(localized: "An application conflict error occurred.", bundle: .module)
        case .cancelled:
          return String(localized: "The operation was cancelled.", bundle: .module)
      }
    }

    public var failureReason: String? {
      switch self {
        case .unsupportedFileType(let type):
          return String(
            localized: "The file type \"\(type)\" cannot be automatically installed.",
            bundle: .module
          )
        case .appInUse:
          return String(
            localized: "The application is currently running and cannot be replaced.",
            bundle: .module
          )
        case .cancelled:
          return String(
            localized: "The installation was cancelled by the user.",
            bundle: .module
          )
      }
    }

    public var recoverySuggestion: String? {
      switch self {
        case .unsupportedFileType:
          return String(
            localized: "Open the downloaded file to install manually.",
            bundle: .module
          )
        case .appInUse:
          return String(
            localized: "Save your work and quit the application, then try again.",
            bundle: .module
          )
        case .cancelled:
          return nil
      }
    }
  }

  /// Progress information during installation
  public struct InstallProgress: Sendable {
    public let phase: InstallPhase
    public let message: String

    public init(phase: InstallPhase, message: String) {
      self.phase = phase
      self.message = message
    }
  }

  /// The current phase of the installation process
  public enum InstallPhase: Sendable, Equatable {
    /// Preparing for installation
    case preparing

    /// Mounting a DMG file
    case mounting

    /// Extracting a ZIP file
    case extracting

    /// Copying the application to the destination
    case copying

    /// Verifying the installed application
    case verifying

    /// Unmounting the DMG file
    case unmounting

    /// Cleaning up temporary files
    case cleaning

    /// Installation complete
    case complete

    /// A user-friendly description of the phase
    public var displayName: String {
      switch self {
        case .preparing:
          return "Preparing..."
        case .mounting:
          return "Opening disk image..."
        case .extracting:
          return "Extracting update..."
        case .copying:
          return "Installing update..."
        case .verifying:
          return "Verifying installation..."
        case .unmounting:
          return "Cleaning up..."
        case .cleaning:
          return "Cleaning up..."
        case .complete:
          return "Installation complete"
      }
    }
  }

  /// The type of installable asset
  public enum InstallableType: Sendable, Equatable {
    case dmg
    case zip
    case pkg

    /// File extensions associated with this type
    public var fileExtensions: [String] {
      switch self {
        case .dmg:
          return ["dmg"]
        case .zip:
          return ["zip"]
        case .pkg:
          return ["pkg", "mpkg"]
      }
    }

    /// Whether this type supports automatic installation
    public var supportsAutoInstall: Bool {
      switch self {
        case .dmg, .zip:
          return true
        case .pkg:
          return false  // PKG requires Installer.app or command-line installer
      }
    }
  }
#endif
