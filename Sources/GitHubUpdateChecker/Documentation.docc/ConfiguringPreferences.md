# Configuring Preferences

Customize update checking behavior and manage user preferences.

## Overview

GitHubUpdateChecker stores user preferences in `UserDefaults`, allowing users to
control how often updates are checked and which versions to skip. You can access
these preferences through the ``UpdatePreferences`` class.

## Accessing Preferences

Use the shared instance for most cases:

```swift
let prefs = UpdatePreferences.shared
```

Or create a custom instance with a specific `UserDefaults` suite:

```swift
let customDefaults = UserDefaults(suiteName: "com.myapp.updates")!
let prefs = UpdatePreferences(defaults: customDefaults)
```

## Update Cadence

Control how frequently automatic checks occur:

```swift
// Check daily (default)
prefs.updateCadence = .daily

// Check more frequently during beta periods
prefs.updateCadence = .hourly

// Check less frequently for stable apps
prefs.updateCadence = .weekly

// Disable automatic checks entirely
prefs.updateCadence = .never
```

Users can still manually check for updates when cadence is set to `.never`.

## Including Prereleases

By default, only stable releases are considered. Enable prereleases for beta
testers:

```swift
prefs.checkForPrereleases = true
```

This fetches all releases and returns the newest non-draft release, regardless
of its prerelease status.

## Skipping Versions

Users can skip specific versions to avoid repeated prompts:

```swift
// Skip a version programmatically
let version = SemanticVersion(major: 2, minor: 0, patch: 0)
prefs.skipVersion(version)

// Check if a version is skipped
if prefs.isVersionSkipped(version) {
    print("User chose to skip version 2.0.0")
}

// Clear all skipped versions
prefs.resetSkippedVersions()
```

The update dialog's "Skip This Version" button automatically calls
``UpdatePreferences/skipVersion(_:)``.

## Automatic Downloads

Enable automatic downloading when an update is found:

```swift
prefs.automaticDownload = true
```

> Note: This setting is available but the default UI always prompts the user
> before downloading.

## Building a Settings UI

Since ``UpdatePreferences`` is `@Observable`, you can easily build a settings
view:

```swift
import SwiftUI
import GitHubUpdateChecker

struct UpdateSettingsView: View {
    let preferences = UpdatePreferences.shared

    var body: some View {
        Form {
            Picker("Check for updates", selection: $preferences.updateCadence) {
                ForEach(UpdateCadence.allCases, id: \.self) { cadence in
                    Text(cadence.displayName).tag(cadence)
                }
            }

            Toggle("Include prereleases", isOn: $preferences.checkForPrereleases)

            if !preferences.skippedVersions.isEmpty {
                Section("Skipped Versions") {
                    ForEach(Array(preferences.skippedVersions), id: \.self) { version in
                        Text(version.description)
                    }

                    Button("Clear Skipped Versions") {
                        preferences.resetSkippedVersions()
                    }
                }
            }
        }
    }
}
```

## Resetting to Defaults

Reset all preferences to their default values:

```swift
prefs.resetToDefaults()
```

This sets:
- `updateCadence` to `.daily`
- `automaticDownload` to `false`
- `checkForPrereleases` to `false`
- Clears `lastCheckTimestamp`
- Clears `skippedVersions`

## UserDefaults Keys

Preferences are stored with the prefix `tim.codes.GitHubUpdateChecker.`:

| Key | Type | Description |
|-----|------|-------------|
| `updateCadence` | String | Raw value of ``UpdateCadence`` |
| `automaticDownload` | Bool | Auto-download setting |
| `lastCheckTimestamp` | Double | Unix timestamp of last check |
| `skippedVersions` | [String] | Array of skipped version strings |
| `checkForPrereleases` | Bool | Include prereleases setting |

## Topics

### Related Types

- ``UpdatePreferences``
- ``UpdateCadence``
