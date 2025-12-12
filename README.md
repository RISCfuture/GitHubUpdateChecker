# GitHubUpdateChecker

[![Build and Test](https://github.com/riscfuture/GitHubUpdateChecker/actions/workflows/ci.yml/badge.svg)](https://github.com/riscfuture/GitHubUpdateChecker/actions/workflows/ci.yml)
[![Documentation](https://github.com/riscfuture/GitHubUpdateChecker/actions/workflows/documentation.yml/badge.svg)](https://riscfuture.github.io/GitHubUpdateChecker/)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14+-blue.svg)](https://developer.apple.com/macos/)

A lightweight Swift library for checking app updates via GitHub's Releases API.
Inspired by [Sparkle](https://sparkle-project.org/), but simpler and focused on
GitHub-hosted releases.

## Features

- **Automatic Update Checking**: Configurable check cadence (hourly, daily, weekly)
- **Modern SwiftUI Interface**: Native update dialog with Markdown-rendered release notes
- **Flexible Downloads**: Automatically adapts to your app's sandbox entitlements
- **Version Management**: Skip versions, remind later, or download immediately
- **No Authentication Required**: Works with public GitHub repositories
- **Swift Concurrency**: Built with async/await and actors for thread safety

## Requirements

- macOS 14.0+
- Swift 6.0+

## Installation

### Swift Package Manager

Add GitHubUpdateChecker to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/riscfuture/GitHubUpdateChecker.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Quick Start

### Basic Integration

```swift
import GitHubUpdateChecker
import SwiftUI

@main
struct MyApp: App {
    let updateChecker = GitHubUpdateChecker(owner: "username", repo: "myapp")

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task { await updateChecker.checkForUpdatesAndShowUI() }
                }
                .disabled(!updateChecker.canCheckForUpdates)
            }
        }
    }

    init() {
        updateChecker.startAutomaticChecks()
    }
}
```

### Manual Update Checking

```swift
let checker = GitHubUpdateChecker(owner: "username", repo: "myapp")

// Check for updates without showing UI
let result = try await checker.checkForUpdates()

switch result {
case .updateAvailable(let release):
    print("New version available: \(release.version)")
case .noUpdateAvailable:
    print("You’re up to date!")
case .skippedVersion(let release):
    print("Version \(release.version) was skipped")
case .error(let error):
    print("Error checking: \(error)")
}
```

### Configuring Update Preferences

```swift
let prefs = UpdatePreferences.shared

// Set check frequency
prefs.updateCadence = .weekly  // .hourly, .daily, .weekly, .never

// Include prereleases in update checks
prefs.checkForPrereleases = true

// Skip a specific version
prefs.skipVersion("2.0.0")

// Check if a version was skipped
if prefs.isVersionSkipped("2.0.0") {
    print("User skipped version 2.0.0")
}

// Reset all skipped versions
prefs.resetSkippedVersions()
```

### Downloading Updates

```swift
// Download programmatically with progress
await checker.downloadUpdate(release)

// Or use the built-in UI which shows progress
await checker.checkForUpdatesAndShowUI()
```

## How It Works

1. **Version Detection**: The library uses your app's `CFBundleShortVersionString`
   (or a custom version you provide) and compares it against GitHub release tags.

2. **GitHub API**: Fetches releases from `https://api.github.com/repos/{owner}/{repo}/releases`
   without requiring authentication for public repositories.

3. **Asset Selection**: Automatically finds downloadable assets prioritizing `.dmg`,
   `.zip`, and `.pkg` files.

4. **Preferences Storage**: User preferences (cadence, skipped versions) are stored
   in UserDefaults with the prefix `tim.codes.GitHubUpdateChecker.`

## Update Dialog

When an update is available, the library displays a native SwiftUI dialog showing:

- App icon and version comparison
- Release date
- Markdown-rendered release notes
- Three action buttons:
  - **Skip This Version**: Permanently ignore this version
  - **Remind Me Later**: Dismiss and check again next time
  - **Download Update**: Download the update asset

## Download Behavior

GitHubUpdateChecker automatically adapts to your app's sandbox entitlements:

| Entitlement | Behavior |
|-------------|----------|
| `com.apple.security.files.downloads.read-write` | Downloads directly to ~/Downloads |
| `com.apple.security.files.user-selected.read-write` | Prompts user to select save location via NSSavePanel |
| Neither | Opens the download URL in the user's browser |

This means the library works out of the box regardless of your app's sandbox configuration.

> **Note**: Your app must have the `com.apple.security.network.client` (Outgoing Connections)
> entitlement to communicate with the GitHub API.

## Documentation

Full API documentation is available at
https://riscfuture.github.io/GitHubUpdateChecker/documentation/githubupdatechecker/

To generate documentation locally:

```sh
swift package generate-documentation --target GitHubUpdateChecker
```

## Tests

Run tests with Swift Package Manager:

```sh
swift test
```

## Known Issues

### Swift 6.1 Compatibility

This library does not compile with Swift 6.1. Swift 6.0 and 6.2+ are fully
supported.

The issue is in a transitive dependency: `NetworkImage` (via `swift-markdown-ui`)
includes a `Package@swift-6.0.swift` manifest that opts into Swift 6 language
mode, but contains code that fails Swift 6.1's stricter concurrency checking
around `@StateObject` initialization. Apple relaxed these rules in Swift 6.2.

**Workarounds:**
- Use Swift 6.0 or Swift 6.2+
- Wait for upstream fix in the [NetworkImage](https://github.com/gonzalezreal/NetworkImage) library

## License

MIT License. See [LICENSE](LICENSE) for details.
