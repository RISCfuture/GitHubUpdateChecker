#if os(macOS)
  import Foundation
  import Testing

  @testable import GitHubUpdateChecker

  @Suite("PrivilegeEscalation")
  struct PrivilegeEscalationTests {
    @Test("Existing read-only destination in a writable directory")
    func readOnlyDestination() throws {
      try withTemporaryDirectory { directory in
        let bundle = directory.appending(component: "Installed.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: false)
        try FileManager.default.setAttributes(
          [.posixPermissions: 0o555],
          ofItemAtPath: bundle.path
        )

        #expect(PrivilegeEscalation.requiresElevation(for: bundle))
      }
    }

    @Test("Destination that does not exist yet in a writable directory")
    func newDestination() throws {
      try withTemporaryDirectory { directory in
        let destination = directory.appending(component: "New.app")

        #expect(!PrivilegeEscalation.requiresElevation(for: destination))
      }
    }

    /// Runs a test against a fresh temporary directory, restoring write permission throughout the
    /// tree afterward so that a destination the test made read-only can still be deleted.
    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
      let directory = URL.temporaryDirectory.appending(
        component: "PrivilegeEscalationTests-\(UUID().uuidString)"
      )
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer {
        makeTreeWritable(at: directory)
        try? FileManager.default.removeItem(at: directory)
      }

      try body(directory)
    }

    private func makeTreeWritable(at directory: URL) {
      let descendants =
        FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)?
        .compactMap { $0 as? URL } ?? []
      for url in [directory] + descendants {
        try? FileManager.default.setAttributes(
          [.posixPermissions: 0o755],
          ofItemAtPath: url.path
        )
      }
    }
  }
#endif
