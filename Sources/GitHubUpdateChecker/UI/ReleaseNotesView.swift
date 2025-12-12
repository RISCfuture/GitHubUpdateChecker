//
//  ReleaseNotesView.swift
//  GitHubUpdateChecker
//
//  A reusable SwiftUI view for displaying Markdown-formatted release notes.
//

import MarkdownUI
import SwiftUI

/// A SwiftUI view that displays release notes with Markdown rendering.
///
/// Use this view when building custom update UIs to display release notes
/// from a ``GitHubRelease``. The view automatically handles empty content
/// with a placeholder message and renders Markdown formatting.
///
/// ## Usage
///
/// ```swift
/// // Basic usage with a release
/// if let release = checker.latestRelease {
///     ReleaseNotesView(release: release)
///         .frame(height: 200)
/// }
///
/// // Or with raw markdown content
/// ReleaseNotesView(markdown: "## What's New\n\n- Feature 1\n- Bug fix")
///     .frame(height: 200)
/// ```
///
/// The view includes:
/// - Markdown rendering via MarkdownUI
/// - Text selection support
/// - Automatic scrolling for long content
/// - Rounded background matching system text background color
/// - Placeholder text when no release notes are available
public struct ReleaseNotesView: View {
  private let content: String?

  public var body: some View {
    ScrollView {
      if let content, !content.isEmpty {
        Markdown(content)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Text("No release notes for this version.", bundle: .module)
          .foregroundStyle(.secondary)
          .italic()
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(12)
    .background(Color(nsColor: .textBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  /// Creates a release notes view from a GitHub release.
  ///
  /// - Parameter release: The release containing the notes to display.
  public init(release: GitHubRelease) {
    self.content = release.body
  }

  /// Creates a release notes view from raw Markdown content.
  ///
  /// - Parameter markdown: The Markdown-formatted release notes, or `nil` if none.
  public init(markdown: String?) {
    self.content = markdown
  }
}
