# Getting Started

Learn how to integrate GitHubUpdateChecker into your macOS app.

## Overview

GitHubUpdateChecker makes it easy to notify users when a new version of your app
is available on GitHub. This guide walks you through basic setup and common
integration patterns.

## Requirements

- macOS 14.0 or later
- Swift 6.0 or later
- A public GitHub repository with releases

## Installation

Add GitHubUpdateChecker to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/riscfuture/GitHubUpdateChecker.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

## Basic Integration

The simplest integration adds a "Check for Updates" menu item and enables
automatic background checks:

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

> Note: Your app must have the `com.apple.security.network.client` (Outgoing Connections)
> entitlement to communicate with the GitHub API.

### What This Does

1. Creates an update checker configured for your GitHub repository
2. Adds a "Check for Updates…" menu item to the app menu
3. Starts automatic background checks based on the user's preferred cadence

## Manual Update Checking

For more control over the update flow, check for updates manually and handle
the result:

```swift
let checker = GitHubUpdateChecker(owner: "username", repo: "myapp")

let result = try await checker.checkForUpdates()

switch result {
case .updateAvailable(let release):
    print("Version \(release.version) is available!")
    print("Release notes: \(release.body ?? "None")")

case .noUpdateAvailable:
    print("You’re running the latest version.")

case .skippedVersion(let release):
    print("Version \(release.version) was skipped.")

case .error(let error):
    print("Error checking for updates: \(error.localizedDescription)")
}
```

## Specifying a Custom Version

By default, GitHubUpdateChecker uses your app's `CFBundleShortVersionString`.
You can override this:

```swift
let checker = GitHubUpdateChecker(
    owner: "username",
    repo: "myapp",
    currentVersion: SemanticVersion(major: 2, minor: 0, patch: 0)
)
```

You can also parse a version string:

```swift
let checker = GitHubUpdateChecker(
    owner: "username",
    repo: "myapp",
    currentVersion: SemanticVersion("2.0.0")
)
```

## Asset Selection

GitHubUpdateChecker automatically selects the best downloadable asset from a
release, prioritizing `.dmg`, `.zip`, and `.pkg` files.

For releases with multiple assets, specify a pattern:

```swift
let checker = GitHubUpdateChecker(owner: "username", repo: "myapp")
checker.assetPattern = ".*-arm64\\.dmg$"  // Match ARM64 DMG files
```

## How Version Comparison Works

GitHubUpdateChecker uses ``SemanticVersion`` for version comparison. Versions are
parsed and compared numerically:

- Prefixes like `v` or `version` are stripped
- Components are compared numerically (`1.9.0` < `1.10.0`)
- Missing components default to 0 (`1.0` = `1.0.0`)
- Prerelease suffixes are stored but not compared (`1.0.0-beta` = `1.0.0`)

Since ``SemanticVersion`` conforms to `Comparable`, you can compare versions directly:

```swift
let v1 = SemanticVersion("1.2.0")!
let v2 = SemanticVersion("2.0.0")!

if v1 < v2 {
    print("Update available!")
}
```

## Update Dialog

When an update is available, ``GitHubUpdateChecker/GitHubUpdateChecker/checkForUpdatesAndShowUI()``
displays a native dialog with:

- Your app icon and name
- Version comparison (current vs. available)
- Release date
- Markdown-rendered release notes
- Action buttons:
  - **Skip This Version**: Adds the version to the skip list
  - **Remind Me Later**: Dismisses without action
  - **Download Update**: Downloads the update asset

## Download Behavior

GitHubUpdateChecker automatically adapts to your app's sandbox configuration:

| Entitlement | Behavior |
|-------------|----------|
| `com.apple.security.files.downloads.read-write` | Downloads directly to ~/Downloads |
| `com.apple.security.files.user-selected.read-write` | Shows NSSavePanel for user to choose location |
| Neither | Opens the download URL in the default browser |

This means the library works correctly regardless of your app's sandbox entitlements,
with no additional configuration required.

> Note: Your app must have the `com.apple.security.network.client` (Outgoing Connections)
> entitlement to communicate with the GitHub API.
