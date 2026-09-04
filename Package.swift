// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let upcomingFeatures: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("InferIsolatedConformances"),
  .enableUpcomingFeature("ImmutableWeakCaptures"),
  .enableUpcomingFeature("MemberImportVisibility"),
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault")
]

let package = Package(
  name: "GitHubUpdateChecker",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "GitHubUpdateChecker",
      targets: ["GitHubUpdateChecker"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0"),
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1"),
    .package(url: "https://github.com/apple/swift-log", from: "1.15.0")
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "GitHubUpdateChecker",
      dependencies: [
        .product(name: "MarkdownUI", package: "swift-markdown-ui"),
        .product(name: "Logging", package: "swift-log")
      ],
      resources: [
        .process("Resources")
      ],
      swiftSettings: upcomingFeatures
    ),
    .testTarget(
      name: "GitHubUpdateCheckerTests",
      dependencies: ["GitHubUpdateChecker"],
      swiftSettings: upcomingFeatures
    )
  ],
  swiftLanguageModes: [.v5, .v6]
)
