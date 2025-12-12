import Foundation
import Logging

/// Manages automatic periodic update checks
@MainActor
public final class UpdateScheduler {
  // MARK: - Properties

  private var scheduledTask: Task<Void, Never>?
  private let preferences: UpdatePreferences
  private let checkAction: @MainActor () async -> Void
  private let logger = Logger(label: "codes.tim.GitHubUpdateChecker.Scheduler")

  /// Check if automatic updates are currently scheduled
  public var isRunning: Bool {
    scheduledTask != nil && !scheduledTask!.isCancelled
  }

  // MARK: - Initialization

  /// Creates a new update scheduler
  /// - Parameters:
  ///   - preferences: The preferences instance to read cadence from
  ///   - checkAction: The action to perform when checking for updates
  public init(
    preferences: UpdatePreferences = .shared,
    checkAction: @escaping @MainActor () async -> Void
  ) {
    self.preferences = preferences
    self.checkAction = checkAction
  }

  // MARK: - Public Methods

  /// Start automatic update checking based on the configured cadence
  public func start() {
    stop()

    guard preferences.updateCadence != .never else {
      logger.info(
        "Automatic updates disabled",
        metadata: [
          "cadence": "\(preferences.updateCadence.rawValue)"
        ]
      )
      return
    }

    logger.info(
      "Starting automatic update scheduler",
      metadata: [
        "cadence": "\(preferences.updateCadence.rawValue)",
        "interval": "\(preferences.updateCadence.timeInterval ?? 0)"
      ]
    )

    scheduledTask = Task { [weak self] in
      await self?.runScheduleLoop()
    }
  }

  /// Stop automatic update checking
  public func stop() {
    if scheduledTask != nil {
      logger.info("Stopping automatic update scheduler")
    }
    scheduledTask?.cancel()
    scheduledTask = nil
  }

  /// Trigger an immediate check if enough time has passed since the last check
  public func checkIfDue() async {
    if shouldCheckNow() {
      await checkAction()
    }
  }

  // MARK: - Private Methods

  private func runScheduleLoop() async {
    while !Task.isCancelled {
      // Check if we should run now
      if shouldCheckNow() {
        logger.debug("Triggering scheduled update check")
        await checkAction()
      }

      // Calculate time until next check
      guard let interval = preferences.updateCadence.timeInterval else {
        logger.debug("No interval configured, exiting schedule loop")
        return
      }

      let sleepDuration = calculateSleepDuration(interval: interval)

      logger.debug(
        "Sleeping until next check",
        metadata: [
          "sleepSeconds": "\(Int(sleepDuration))",
          "nextCheckAt": "\(Date().addingTimeInterval(sleepDuration))"
        ]
      )

      do {
        try await Task.sleep(for: .seconds(sleepDuration))
      } catch {
        logger.debug("Schedule loop cancelled")
        return
      }
    }
  }

  private func shouldCheckNow() -> Bool {
    guard let interval = preferences.updateCadence.timeInterval else {
      return false
    }

    guard let lastCheck = preferences.lastCheckTimestamp else {
      // Never checked before, should check now
      return true
    }

    let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
    return timeSinceLastCheck >= interval
  }

  private func calculateSleepDuration(interval: TimeInterval) -> TimeInterval {
    if let lastCheck = preferences.lastCheckTimestamp {
      let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
      let remaining = interval - timeSinceLastCheck

      // If we've passed the interval, wait the full interval
      if remaining <= 0 {
        return interval
      }

      return remaining
    }

    return interval
  }
}
