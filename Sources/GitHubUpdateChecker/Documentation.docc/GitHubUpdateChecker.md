# ``GitHubUpdateChecker``

A lightweight Swift library for checking app updates via GitHub's Releases API.

@Metadata {
    @DisplayName("GitHubUpdateChecker")
}

## Overview

GitHubUpdateChecker provides a simple way to check for updates to your macOS app
by querying GitHub's Releases API. Inspired by [Sparkle](https://sparkle-project.org/),
it offers a modern Swift implementation with async/await support and SwiftUI integration.

### Key Features

- **Automatic Update Checking**: Schedule checks hourly, daily, or weekly
- **Native SwiftUI Interface**: Beautiful update dialogs with Markdown-rendered release notes
- **Flexible Downloads**: Adapts to your app's sandbox entitlements automatically
- **Version Management**: Users can skip versions or be reminded later
- **Move to Applications**: Prompt users to install your app properly on first launch
- **No Authentication Required**: Works with any public GitHub repository

### Quick Start

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
            }
        }
    }

    init() {
        updateChecker.startAutomaticChecks()
    }
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- ``GitHubUpdateChecker/GitHubUpdateChecker``

### Configuration

- <doc:ConfiguringPreferences>
- <doc:SwiftUIIntegration>
- <doc:MovingToApplications>
- ``UpdatePreferences``
- ``UpdateCadence``

### Installation

- ``AppMover``

### Update Results

- ``UpdateCheckResult``
- ``UpdateCheckError``

### GitHub API Types

- ``GitHubRelease``
- ``GitHubAsset``

### Version Comparison

- ``SemanticVersion``
