# ``GitHubUpdateChecker/GitHubUpdateChecker``

The main entry point for checking GitHub releases for updates.

## Overview

`GitHubUpdateChecker` is an `@Observable` class that manages the entire update
checking lifecycle. It handles:

- Automatic background checks on a configurable schedule
- Manual update checks with UI feedback
- Downloading assets with progress tracking
- Version comparison and skip list management

## Topics

### Creating an Update Checker

- ``init(owner:repo:currentVersion:preferences:)``

### Configuration

- ``owner``
- ``repo``
- ``currentVersion``
- ``assetPattern``
- ``preferences``

### Checking for Updates

- ``checkForUpdates()``
- ``checkForUpdatesAndShowUI()``
- ``showUpdateAlert(for:)``

### Automatic Checking

- ``startAutomaticChecks()``
- ``stopAutomaticChecks()``
- ``isAutomaticCheckingEnabled``

### Download Management

- ``downloadUpdate(_:)``
- ``cancelDownload()``
- ``isDownloading``
- ``downloadProgress``

### State

- ``canCheckForUpdates``
- ``lastCheckDate``
- ``latestRelease``

### Convenience

- ``releasesURL``
- ``openReleasesPage()``
