# SwiftUI Integration

Options for integrating update checking into a SwiftUI app, from zero-configuration to fully custom.

## Overview

GitHubUpdateChecker provides a spectrum of integration options. Choose the level that matches your needs:

| Level | Effort | What You Control |
|-------|--------|------------------|
| **Zero Config** | ~10 lines | Nothing - built-in UI handles everything |
| **Custom Presentation** | ~30 lines | When/how the update window appears |
| **Fully Custom UI** | ~150 lines | Complete control over appearance and behavior |

## Zero Config Integration

The simplest approach. The library provides a complete, polished update experience:

```swift
@main
struct MyApp: App {
    @State private var checker = GitHubUpdateChecker(
        owner: "user",
        repo: "app",
        currentVersion: SemanticVersion(major: 1, minor: 0, patch: 0)
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task { await checker.checkForUpdatesAndShowUI() }
                }
                .disabled(!checker.canCheckForUpdates)
            }
        }
    }

    init() {
        checker.startAutomaticChecks()
    }
}
```

The built-in UI handles:
- Update available alert with release notes
- Download progress with cancel option
- Download completion with install option
- Installation progress
- Restart prompt

## Custom Presentation

Control when and how the update UI appears while using the built-in window:

### Environment-Based Window

Use SwiftUI's `@Environment(\.openWindow)` to trigger the update check from anywhere:

```swift
@main
struct MyApp: App {
    @State private var checker = GitHubUpdateChecker(
        owner: "user",
        repo: "app",
        currentVersion: SemanticVersion(major: 1, minor: 0, patch: 0)
    )

    var body: some Scene {
        WindowGroup {
            ContentView(checker: checker)
        }

        Window("Software Update", id: "update-window") {
            if let release = checker.latestRelease {
                UpdateWindowContent(checker: checker, release: release)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    let checker: GitHubUpdateChecker
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MainContent()
            .task {
                let result = try? await checker.checkForUpdates()
                if case .updateAvailable = result {
                    openWindow(id: "update-window")
                }
            }
    }
}
```

### Sheet-Based Trigger

Present updates as a sheet from your main window:

```swift
struct ContentView: View {
    let checker: GitHubUpdateChecker
    @State private var showingUpdate = false

    var body: some View {
        MainContent()
            .sheet(isPresented: $showingUpdate) {
                // Use your own view or the pattern from "Fully Custom UI"
            }
            .task {
                let result = try? await checker.checkForUpdates()
                if case .updateAvailable = result {
                    showingUpdate = true
                }
            }
    }
}
```

## Fully Custom UI

Build your own update experience using the library's state properties and methods.

### Building Blocks

**ReleaseNotesView** - A ready-to-use Markdown renderer for release notes:

```swift
ReleaseNotesView(release: release)
    .frame(height: 200)

// Or with raw markdown
ReleaseNotesView(markdown: "## What's New\n\n- Feature 1")
```

**State Properties** - Observe these on `GitHubUpdateChecker`:

- `latestRelease` - The release found by `checkForUpdates()`
- `isDownloading` / `downloadProgress` - Download state (0.0 to 1.0)
- `downloadedFileURL` - Location of completed download
- `isInstalling` / `installationPhase` - Installation state and current phase
- `installedAppURL` - Location of installed app when complete

**Methods** - Drive the update flow:

- `checkForUpdates()` - Check without showing UI
- `downloadUpdate(_:)` - Download a release
- `cancelDownload()` - Cancel in-progress download
- `installUpdate(from:to:)` - Install a downloaded file
- `relaunchApp()` - Restart the application

### Complete Example

A full custom implementation with state machine:

```swift
struct UpdateSheetView: View {
    let checker: GitHubUpdateChecker
    let release: GitHubRelease
    @Binding var isPresented: Bool

    private enum State {
        case initial, downloading, downloadComplete, installing, installComplete
    }

    private var currentState: State {
        if checker.installedAppURL != nil && !checker.isInstalling {
            return .installComplete
        } else if checker.isInstalling {
            return .installing
        } else if checker.downloadedFileURL != nil && !checker.isDownloading {
            return .downloadComplete
        } else if checker.isDownloading {
            return .downloading
        }
        return .initial
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            content
            buttons
        }
        .padding()
        .frame(width: 450)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Image(systemName: headerIcon)
                .font(.largeTitle)
                .foregroundStyle(headerColor)

            VStack(alignment: .leading) {
                Text(headerTitle).font(.headline)
                Text(headerSubtitle).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var headerIcon: String {
        switch currentState {
        case .initial, .downloading: "arrow.down.app.fill"
        case .downloadComplete, .installComplete: "checkmark.circle.fill"
        case .installing: "gearshape.2.fill"
        }
    }

    private var headerColor: Color {
        switch currentState {
        case .initial, .downloading: .blue
        case .downloadComplete, .installComplete: .green
        case .installing: .orange
        }
    }

    private var headerTitle: String {
        switch currentState {
        case .initial, .downloading: "Update Available"
        case .downloadComplete: "Download Complete"
        case .installing: "Installing..."
        case .installComplete: "Update Installed"
        }
    }

    private var headerSubtitle: String {
        switch currentState {
        case .initial, .downloading:
            release.version?.description ?? release.tagName
        case .downloadComplete:
            checker.downloadedFileURL?.lastPathComponent ?? ""
        case .installing:
            checker.installationPhase ?? "Please wait..."
        case .installComplete:
            "Restart to use the new version"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch currentState {
        case .initial, .downloading:
            ReleaseNotesView(release: release)
                .frame(height: 200)
            if checker.isDownloading {
                ProgressView(value: checker.downloadProgress)
            }

        case .installing:
            VStack {
                ProgressView()
                    .controlSize(.large)
                if let phase = checker.installationPhase {
                    Text(phase).foregroundStyle(.secondary)
                }
            }

        case .downloadComplete, .installComplete:
            EmptyView()
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch currentState {
        case .initial:
            HStack {
                Button("Skip") {
                    if let v = release.version { checker.preferences.skipVersion(v) }
                    isPresented = false
                }
                Spacer()
                Button("Later") { isPresented = false }
                Button("Download") { Task { await checker.downloadUpdate(release) } }
                    .keyboardShortcut(.defaultAction)
            }

        case .downloading:
            HStack {
                Spacer()
                Button("Cancel") { Task { await checker.cancelDownload() } }
            }

        case .downloadComplete:
            HStack {
                Button("Close") { isPresented = false }
                Spacer()
                if let url = checker.downloadedFileURL {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    Button("Install") { Task { await checker.installUpdate(from: url) } }
                        .keyboardShortcut(.defaultAction)
                }
            }

        case .installing:
            EmptyView()

        case .installComplete:
            HStack {
                Button("Later") { isPresented = false }
                Spacer()
                Button("Restart Now") { checker.relaunchApp() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
```

## Topics

### Views

- ``ReleaseNotesView``

### State Properties

- ``GitHubUpdateChecker/latestRelease``
- ``GitHubUpdateChecker/isDownloading``
- ``GitHubUpdateChecker/downloadProgress``
- ``GitHubUpdateChecker/downloadedFileURL``
- ``GitHubUpdateChecker/isInstalling``
- ``GitHubUpdateChecker/installationPhase``
- ``GitHubUpdateChecker/installedAppURL``
- ``GitHubUpdateChecker/canCheckForUpdates``

### Methods

- ``GitHubUpdateChecker/checkForUpdates()``
- ``GitHubUpdateChecker/downloadUpdate(_:)``
- ``GitHubUpdateChecker/installUpdate(from:to:)``
- ``GitHubUpdateChecker/cancelDownload()``
- ``GitHubUpdateChecker/relaunchApp(appURL:)``

### Related

- <doc:GettingStarted>
- ``GitHubUpdateChecker``
