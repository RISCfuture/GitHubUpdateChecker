# Change Log

## [2.1.0] - 2026-08-30

### Added

- `.pkg` assets are now installed automatically. `AppInstaller` hands a package
  to `installer(8)` through the same administrator prompt the privileged copy
  already used, instead of extracting a bundle and copying it into place — a
  package chooses its own destination, so the install is verified afterwards
  rather than aimed beforehand. `InstallableType.pkg.supportsAutoInstall` is
  now `true`, and a project shipping an installer package no longer has to
  publish a disk image beside it purely to give the updater something it knows
  how to install.
- `AppInstaller.canAutoInstall(fileURL:)`, which answers whether a downloaded
  file can be installed without the user doing it by hand. It replaces the
  extension checks that `GitHubUpdateChecker.canAutoInstall(fileURL:)` and the
  update alert each kept a copy of.
- `InstallableType.init?(fileURL:)`, which identifies a file's installable type.

### Fixed

- A path containing a double quote or a backslash no longer breaks the
  privileged copy. The shell command is now escaped for the AppleScript string
  literal that carries it, a layer the shell quoting knew nothing about.
- A path containing an apostrophe no longer breaks the relaunch, which escaped
  the path for single quotes and then wrapped it in double ones.

## [2.0.1] - 2026-08-28

### Fixed

- Apps installed by a `.pkg` installer can now be updated in place.
  `PrivilegeEscalation.requiresElevation(for:)` only inspected the directory
  enclosing the destination, so a `root:wheel` bundle sitting in a
  group-writable `/Applications` looked replaceable without authorization and
  the install failed while deleting the old bundle. It now also checks the item
  being replaced, so these installs take the administrator-authorized path.

## [2.0.0] - 2026-06-26

### Changed

- **Breaking:** `UpdateDownloader.download(asset:to:)` now returns a live
  `AsyncThrowingStream<DownloadProgress, Error>` alongside the destination URL.
  Consume progress with `for try await progress in stream`. Progress is now
  reported as bytes arrive (the previous variant buffered all progress until the
  download had already finished), and failure or cancellation is surfaced by the
  stream throwing.
- **Breaking:** `AppInstaller.install(from:to:)` now returns an
  `AsyncThrowingStream<InstallProgress, Error>` alongside the installed app URL,
  replacing the progress-callback API.
- Cancelling a download or installation now cancels the in-flight work, not just
  the UI.
- Adopted the Approachable Concurrency upcoming features
  (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`) and migrated to
  modern structured concurrency: subprocess steps (DMG mount/unmount, ZIP
  extraction, quarantine removal) no longer block a concurrency executor thread,
  app relaunch uses the async `NSWorkspace.openApplication` API, and the legacy
  `MainActor.run` hops were removed.

### Removed

- **Breaking:** the `download(asset:to:onProgress:)` completion-callback overload
  on `UpdateDownloader`.

## [1.0.0] - 2026-05-01

Initial release.

- SwiftUI-based update checker that polls the GitHub Releases API for new versions of an app
- "Move to Applications folder" helper
- Built on modern Swift Concurrency
