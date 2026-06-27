#if os(macOS)
  import Foundation

  extension Process {
    // Suspends until the process exits without blocking the calling thread. Unlike
    // `waitUntilExit()`, this bridges the subprocess lifecycle to Swift concurrency via the
    // termination handler, freeing the cooperative executor while the subprocess runs.
    func runUntilExit() async throws {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, Error>) in
        terminationHandler = { _ in continuation.resume() }
        do {
          try run()
        } catch {
          terminationHandler = nil
          continuation.resume(throwing: error)
        }
      }
    }
  }
#endif
