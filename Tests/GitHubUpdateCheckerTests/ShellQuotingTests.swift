#if os(macOS)
  import Foundation
  import Testing

  @testable import GitHubUpdateChecker

  /// Paths that break naive quoting. Each is a real thing a Mac will let someone name a folder.
  private let awkwardPaths = [
    "/Applications/Zephyr.app",
    "/Users/tim/Tim's Apps/Zephyr.app",
    #"/Users/tim/He said "hi"/Zephyr.app"#,
    #"/Users/tim/back\slash/Zephyr.app"#,
    "/Users/tim/$(touch /tmp/pwned)/Zephyr.app",
    "/Users/tim/a b\tc/Zephyr.app"
  ]

  @Suite("Shell quoting")
  struct ShellQuotingTests {
    /// The quoted form has to survive `sh` and come back out byte for byte, which is the only
    /// property the callers actually depend on.
    @Test("A quoted path reaches the shell unchanged", arguments: awkwardPaths)
    func shellQuotedSurvivesTheShell(path: String) throws {
      #expect(try runInShell("printf %s \(path.shellQuoted)") == path)
    }

    /// The shell command is embedded in an AppleScript string literal, so it needs escaping for
    /// AppleScript as well — a layer the quoting above knows nothing about.
    /// `NSAppleScript` is main-thread only, which a test case is not by default.
    @MainActor
    @Test("An escaped command reaches AppleScript unchanged", arguments: awkwardPaths)
    func appleScriptEscapedSurvivesAppleScript(path: String) throws {
      let command = "printf %s \(path.shellQuoted)"
      let script = "return \"\(command.escapedForAppleScriptLiteral)\""

      #expect(try evaluateAppleScript(script) == command)
    }

    private func runInShell(_ command: String) throws -> String {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/bin/sh")
      process.arguments = ["-c", command]

      let output = Pipe()
      process.standardOutput = output
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()

      return String(bytes: data, encoding: .utf8) ?? ""
    }

    @MainActor
    private func evaluateAppleScript(_ source: String) throws -> String {
      // swiftlint:disable:next legacy_objc_type
      var error: NSDictionary?
      let script = try #require(NSAppleScript(source: source))
      let result = script.executeAndReturnError(&error)

      #expect(error == nil)
      return result.stringValue ?? ""
    }
  }
#endif
