# Moving to Applications Folder

Prompt users to move your app to the Applications folder on first launch.

## Overview

When users download your app from a website or GitHub release, they often run it
directly from the Downloads folder. This can cause issues with Gatekeeper's
App Translocation feature and makes it harder for users to find your app later.

``AppMover`` provides a simple API to prompt users to move your app to the
Applications folder on first launch. If the user declines, they won't be asked again.

## Basic Integration

Call ``AppMover/moveToApplicationsFolderIfNeeded()`` early in your app's launch
sequence:

```swift
import GitHubUpdateChecker
import SwiftUI

@main
struct MyApp: App {
    init() {
        AppMover.moveToApplicationsFolderIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

That's all you need. The method handles all the logic internally:

1. Checks if the app is already in an Applications folder
2. Checks if the app can be moved (not sandboxed, not on read-only volume)
3. Checks if the user has previously declined
4. Shows an alert if none of the above conditions apply
5. Moves the app and relaunches if the user agrees

## When the Prompt Appears

The move prompt only appears when all of these conditions are met:

| Condition | Description |
|-----------|-------------|
| Not in Applications | App is not in `/Applications` or `~/Applications` |
| Not sandboxed | App doesn't have App Sandbox enabled |
| Writable location | App is not running from a read-only volume (e.g., DMG) |
| User hasn't declined | User hasn't previously clicked "Don't Move" |

If any condition fails, the method returns silently without showing any UI.

## The User Experience

When the prompt appears, users see a simple alert:

- **Title**: "Move to Applications folder?"
- **Message**: "[App Name] is not in your Applications folder. Would you like to move it there?"
- **Buttons**: "Move to Applications" (default) and "Don't Move"

If the user clicks **Move to Applications**:

1. The app is copied to the preferred Applications folder
2. The original is moved to Trash
3. The quarantine attribute is removed from the new location
4. The app relaunches from the new location

If the user clicks **Don't Move**:

1. The preference is saved so they won't be asked again
2. The app continues running from its current location

## Preferred Applications Folder

When moving, ``AppMover`` automatically chooses between `/Applications` (system)
and `~/Applications` (user) based on which folder contains more apps. This typically
results in `/Applications` being chosen, which may require administrator privileges.

If administrator privileges are needed, the user sees the standard macOS authentication
dialog requesting their password.

## Checking Location Manually

You can check if your app is in an Applications folder without triggering the prompt:

```swift
if AppMover.isInApplicationsFolder {
    print("App is properly installed")
} else {
    print("App is running from: \(Bundle.main.bundlePath)")
}
```

## Resetting the Declined Preference

The user's decision to decline is stored in ``UpdatePreferences/userDeclinedMoveToApplications``.
If you want to allow users to re-enable the prompt (for example, in a settings screen),
you can reset this preference:

```swift
UpdatePreferences.shared.userDeclinedMoveToApplications = false
```

Or reset all preferences to defaults:

```swift
UpdatePreferences.shared.resetToDefaults()
```

## Requirements

``AppMover`` only works for non-sandboxed apps. If your app uses App Sandbox,
the move functionality is automatically disabled and the prompt never appears.

This is because sandboxed apps cannot:
- Move their own bundle
- Write to `/Applications` without explicit user permission via security-scoped bookmarks
- Relaunch themselves from a different location

If you need this functionality, consider distributing a non-sandboxed version of
your app outside the Mac App Store.

## Combining with Update Checking

A typical integration combines ``AppMover`` with ``GitHubUpdateChecker/GitHubUpdateChecker``:

```swift
import GitHubUpdateChecker
import SwiftUI

@main
struct MyApp: App {
    let updateChecker = GitHubUpdateChecker(owner: "username", repo: "myapp")

    init() {
        // First, offer to move to Applications
        AppMover.moveToApplicationsFolderIfNeeded()

        // Then start automatic update checks
        updateChecker.startAutomaticChecks()
    }

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
}
```

This ensures users are prompted to install your app properly before checking for updates.
